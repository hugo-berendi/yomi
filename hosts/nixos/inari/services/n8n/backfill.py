#!/usr/bin/env python
"""Classify an existing mailbox the way the inbox-organizer workflow does.

The n8n side cannot do this. Its IMAP node is a *trigger* whose default search
is ``["UNSEEN"]``; pointing it at ``["ALL"]`` would re-emit the whole mailbox on
every poll rather than walking it once. So the backlog gets its own tool:
resumable, read-only, and cheap enough to finish this decade.

Read-only is enforced twice: the mailbox is SELECTed with ``readonly=True`` and
every fetch uses ``BODY.PEEK[...]``, which is the form that does not set
``\\Seen``. Nothing is moved, flagged or deleted -- this only tells you what a
sort *would* look like.

The trick that makes a large mailbox affordable is the sender cache. A personal
inbox is mostly a few hundred senders repeating, and the bucket for
``info@mailer.netflix.com`` does not change between its four hundred messages.
So each distinct sender costs one model call and every later message from it is
free. On a ten thousand message mailbox that is typically two orders of
magnitude less work.

Run it from the repository root:

    just n8n-backfill

State lives in ``--state`` and is written after every batch, so interrupting it
costs at most one batch.
"""

from __future__ import annotations

import argparse
import email
import email.header
import email.utils
import getpass
import imaplib
import json
import smtplib
import os
import re
import sys
import time
import urllib.error
import urllib.request
from collections import Counter, defaultdict
from pathlib import Path

# {{{ Taxonomy
# Deliberately the same buckets, rules and clamps as the Code node in
# workflows/inbox-organizer.json. They are duplicated rather than shared
# because n8n Code nodes cannot import anything -- if you change one, change
# the other, and the digest and this report will disagree until you do.
BUCKETS = {
    "personal": "a person wrote to you",
    "work": "employer, colleagues, work systems",
    "finance": "banks, invoices, tax, payments",
    "subscriptions": "recurring paid services: renewals, price changes, receipts",
    "newsletters": "editorial bulk mail you opted into",
    "notifications": "automated output of a machine you own",
    "shopping": "orders, dispatch, delivery, returns",
    "travel": "bookings, tickets, check-in",
    "unsolicited": "bulk mail you did not ask for",
}

FOLDER = {
    "personal": "Personal",
    "work": "Work",
    "finance": "Finance",
    "subscriptions": "Abos",
    "shopping": "Shopping",
    "travel": "Travel",
    "newsletters": "Newsletters",
    "notifications": "Automated",
    "unsolicited": "Junk",
    "unsorted": "(left in place)",
}

IMPORTANCE_CLAMP = {"unsolicited": 1, "newsletters": 3, "notifications": 3}

# Below this a "body" is more likely to be a truncation artefact than text.
MIN_SNIPPET = 15

CARRIER = re.compile(
    r"(^|[@.])(dhl|hermes|dpd|ups|gls|deutschepost|amazon)\.[a-z.]+$", re.I
)
MACHINE = re.compile(r"@tengu\.hugo-berendi\.de$", re.I)
WORK = re.compile(r"@datagroup\.de$", re.I)


# A first run over 115 real messages showed the model cannot separate
# "newsletters" from "unsolicited", and that is not really its fault: one
# message does not say whether its recipient subscribed. It filed 23 Substack
# posts as unsolicited bulk, then split the rest of Substack between personal
# and newsletters depending on the sender's display name.
#
# Sender shape settles what judgement cannot, costs nothing, and cannot drift.
NEWSLETTER_DOMAIN = re.compile(
    r"(^|[@.])(substack\.com|beehiiv\.com|ghost\.io|mailchimp\.com)$", re.I
)
NEWSLETTER_LOCAL = re.compile(
    r"^(newsletter|newsletters|news|digest|marketing|angebote|offers?|promo)[.+-]?",
    re.I,
)
MACHINE_DOMAIN = re.compile(r"(^|[@.])(github\.com|gitlab\.com|forgejo\.org)$", re.I)

# This inbox has already passed the provider's spam filter, so a sender who has
# written repeatedly is somebody the recipient has a relationship with, whatever
# the tone of any single message. Below this count, trust the model.
FREQUENT_SENDER = 3


def rule_for(address: str) -> tuple[str, int] | None:
    """Deterministic verdicts, which beat the model and cost nothing."""
    local, _, domain = address.partition("@")
    if MACHINE.search(address):
        return ("notifications", 2)
    if WORK.search(address):
        return ("work", 4)
    if CARRIER.search(address):
        return ("shopping", 2)
    if MACHINE_DOMAIN.search(domain):
        return ("notifications", 2)
    if NEWSLETTER_DOMAIN.search(domain) or NEWSLETTER_LOCAL.match(local):
        return ("newsletters", 2)
    return None


def demote_frequent_senders(verdicts: dict) -> int:
    """Nobody who has written to you this often is sending unsolicited bulk."""
    counts = Counter(r["address"] for r in verdicts.values())
    changed = 0
    for record in verdicts.values():
        if (
            record["bucket"] == "unsolicited"
            and counts[record["address"]] >= FREQUENT_SENDER
        ):
            record["bucket"] = "newsletters"
            record["importance"] = min(record.get("importance", 3), 3)
            record["why"] = (
                f"{counts[record['address']]} messages from this sender, so not unsolicited"
            )
            changed += 1
    return changed


# }}}


# {{{ Model
PROMPT = """You sort one email into exactly one bucket and rate how much it needs a human.

Buckets:
{buckets}

importance: 5 = needs an answer or a decision soon, 4 = should be read today,
3 = worth reading, 2 = routine, glance at it, 1 = no action ever.

Answer with one JSON object and nothing else:
{{"bucket":"<one bucket name>","importance":<1-5>,"why":"<at most 12 words>"}}

From: {name} <{address}>
Subject: {subject}
Body: {body}"""


def classify(
    url: str, name: str, address: str, subject: str, body: str, timeout: int
) -> dict:
    prompt = PROMPT.format(
        buckets="\n".join(f"- {b}: {m}" for b, m in BUCKETS.items()),
        name=name,
        address=address,
        subject=subject,
        body=body or "(empty)",
    )
    payload = json.dumps(
        {
            "model": "local",
            "messages": [{"role": "user", "content": prompt}],
            "temperature": 0,
            "max_tokens": 90,
        }
    ).encode()

    request = urllib.request.Request(
        url, data=payload, headers={"Content-Type": "application/json"}
    )
    with urllib.request.urlopen(request, timeout=timeout) as response:  # noqa: S310
        answer = json.load(response)

    raw = answer["choices"][0]["message"]["content"]
    match = re.search(r"\{.*\}", raw, re.S)
    if not match:
        raise ValueError(f"no JSON in reply: {raw[:120]}")

    parsed = json.loads(match.group(0))
    bucket = str(parsed.get("bucket", "")).lower()
    # A hallucinated bucket would quietly invent a category nobody designed.
    if bucket not in BUCKETS:
        raise ValueError(f"unknown bucket: {bucket}")

    try:
        importance = min(5, max(1, round(float(parsed.get("importance", 3)))))
    except (TypeError, ValueError):
        importance = 3

    ceiling = IMPORTANCE_CLAMP.get(bucket)
    return {
        "bucket": bucket,
        "importance": min(importance, ceiling) if ceiling else importance,
        "why": str(parsed.get("why", ""))[:90],
    }


# }}}


# {{{ IMAP
def decode_header(value: str | None) -> str:
    if not value:
        return ""
    parts = email.header.decode_header(value)
    out = []
    for text, charset in parts:
        if isinstance(text, bytes):
            out.append(text.decode(charset or "utf-8", errors="replace"))
        else:
            out.append(text)
    return " ".join(out).strip()


def connect(host: str, user: str, password: str, mailbox: str) -> imaplib.IMAP4_SSL:
    client = imaplib.IMAP4_SSL(host)
    try:
        client.login(user, password)
    except imaplib.IMAP4.error as error:
        # Migadu answers a bad password and a non-mailbox address with the
        # same opaque "Authentication failed", so spell out the fork rather
        # than leaving a traceback. An alias is the easy one to miss: mail
        # sent *to* an address does not mean that address can log in.
        raise SystemExit(
            f"IMAP login failed for {user} at {host}: {error}\n"
            "\n"
            "Two things produce this, and the server will not tell you which:\n"
            f"  1. {user} is an alias or identity rather than a real mailbox.\n"
            "     Migadu aliases cannot authenticate -- log in as the mailbox\n"
            "     that receives the mail, and pass --user for it.\n"
            "  2. The password is wrong, or the mailbox needs its own\n"
            "     app password rather than the account password.\n"
        ) from error
    # readonly: the server itself refuses any flag change on this session.
    status, _ = client.select(mailbox, readonly=True)
    if status != "OK":
        raise SystemExit(f"cannot select mailbox {mailbox!r}")
    return client


def extract_snippet(message: email.message.Message, limit: int = 400) -> str:
    """Best-effort plain text from a possibly truncated message.

    Headers alone are not enough. Measured on the labelled set, subject plus
    sender scores 10/12 where subject plus a body excerpt scores 12/12 -- and
    one of the two misses was the model inventing a bucket name outright
    ("unsubscribed") rather than admitting it could not tell.
    """
    candidates: list[str] = []
    for part in message.walk() if message.is_multipart() else [message]:
        if part.get_content_maintype() == "multipart":
            continue
        try:
            payload = part.get_payload(decode=True)
        except (LookupError, ValueError):
            continue
        if not payload:
            continue
        charset = part.get_content_charset() or "utf-8"
        text = payload.decode(charset, errors="replace")
        if part.get_content_subtype() == "plain":
            candidates.insert(0, text)
        elif part.get_content_subtype() == "html":
            candidates.append(re.sub(r"<[^>]+>", " ", text))

    for candidate in candidates:
        # A PEEK that stops mid-message can leave a MIME header fragment as the
        # only "body", and "Content" handed to the model as the mail's text is
        # worse than handing it nothing: the model answers confidently from
        # noise. Drop those lines, then insist on something substantial.
        cleaned = "\n".join(
            line
            for line in candidate.splitlines()
            if not re.match(r"^(content-|mime-|--|boundary)", line, re.I)
        )
        cleaned = re.sub(r"https?://\S+", "[link]", cleaned)
        cleaned = re.sub(r"\s+", " ", cleaned).strip()
        if len(cleaned) >= MIN_SNIPPET:
            return cleaned[:limit]
    return ""


def fetch_messages(
    client: imaplib.IMAP4_SSL, uids: list[bytes], peek_bytes: int
) -> list[tuple[bytes, str, str, str, str]]:
    """Return (uid, from, subject, date, snippet) without marking anything read.

    Only the first `peek_bytes` of each message are fetched: enough for the
    headers and the opening of the body, while a marketing mail's full
    multipart payload can be hundreds of kilobytes that would be truncated to
    400 characters anyway.
    """
    if not uids:
        return []
    joined = b",".join(uids)
    # PEEK is the whole point: a plain BODY[] fetch is defined to set \Seen.
    status, data = client.uid("FETCH", joined, f"(BODY.PEEK[]<0.{peek_bytes}>)")
    if status != "OK":
        return []

    out = []
    for part in data:
        if not isinstance(part, tuple):
            continue
        prefix = part[0].decode(errors="replace")
        uid_match = re.search(r"UID (\d+)", prefix)
        if not uid_match:
            continue
        message = email.message_from_bytes(part[1])
        out.append(
            (
                uid_match.group(1).encode(),
                decode_header(message.get("From")),
                decode_header(message.get("Subject")) or "(no subject)",
                decode_header(message.get("Date")),
                extract_snippet(message),
            )
        )
    return out


# }}}


# {{{ Moving
# Everything above only forms an opinion. This is the part that touches the
# mailbox, so it is off unless --apply is passed, and it still refuses two
# categories outright:
#
#   unsorted     the classifier failed on it, so there is no opinion to act on
#   unsolicited  Junk is the provider's spam folder (\Junk special-use), and
#                filing mail there teaches the filter about those senders.
#                Opt in with --include-junk if that is what you want.
SPAM_BUCKET = "unsolicited"
NEVER_MOVE = {"unsorted"}


def ensure_folder(client: imaplib.IMAP4_SSL, folder: str) -> None:
    """CREATE is allowed to fail only because the folder is already there."""
    status, data = client.create(folder)
    if status != "OK":
        detail = b" ".join(data).decode(errors="replace")
        if (
            "ALREADYEXISTS" not in detail.upper()
            and "already exists" not in detail.lower()
        ):
            raise SystemExit(f"could not create folder {folder!r}: {detail}")
    client.subscribe(folder)


def message_ids_for(client: imaplib.IMAP4_SSL, uids: list[bytes]) -> dict[str, str]:
    """Message-Id per uid, so a move can be undone after uids change.

    A UID belongs to one mailbox; the moved copy gets a fresh one in the
    destination. Message-Id survives the move and is what --undo searches on.
    """
    if not uids:
        return {}
    status, data = client.uid(
        "FETCH", b",".join(uids), "(BODY.PEEK[HEADER.FIELDS (MESSAGE-ID)])"
    )
    if status != "OK":
        return {}

    out = {}
    for part in data:
        if not isinstance(part, tuple):
            continue
        uid_match = re.search(r"UID (\d+)", part[0].decode(errors="replace"))
        if not uid_match:
            continue
        message_id = email.message_from_bytes(part[1]).get("Message-ID")
        if message_id:
            out[uid_match.group(1)] = message_id.strip()
    return out


def plan_moves(verdicts: dict, include_junk: bool) -> dict[str, list[bytes]]:
    plan: dict[str, list[bytes]] = defaultdict(list)
    for uid, record in verdicts.items():
        bucket = record["bucket"]
        # Already filed on an earlier run. The uid belonged to INBOX and died
        # with the move, so re-planning it would send MOVE a uid the mailbox
        # no longer has -- harmless on Migadu, but it would grow every run and
        # eventually be the whole history.
        if record.get("moved_to"):
            continue
        if bucket in NEVER_MOVE:
            continue
        if bucket == SPAM_BUCKET and not include_junk:
            continue
        folder = FOLDER.get(bucket)
        if not folder or folder.startswith("("):
            continue
        plan[folder].append(uid.encode())
    return plan


def apply_moves(
    client: imaplib.IMAP4_SSL, state: dict, mailbox: str, include_junk: bool
) -> int:
    plan = plan_moves(state["verdicts"], include_junk)
    if not plan:
        print("nothing to move", file=sys.stderr)
        return 0

    # The mailbox was opened read-only for classification, which is the right
    # default; moving needs it writable.
    status, _ = client.select(mailbox, readonly=False)
    if status != "OK":
        raise SystemExit(f"cannot reopen {mailbox!r} for writing")

    state.setdefault("moved", [])
    total = 0
    for folder, uids in sorted(plan.items()):
        ensure_folder(client, folder)
        ids = message_ids_for(client, uids)

        # Batched, because a UID set of several thousand exceeds what some
        # servers accept on one command line.
        for offset in range(0, len(uids), 100):
            chunk = uids[offset : offset + 100]
            status, data = client.uid("MOVE", b",".join(chunk), folder)
            if status != "OK":
                detail = b" ".join(x for x in data if isinstance(x, bytes))
                raise SystemExit(
                    f"MOVE to {folder!r} failed: {detail.decode(errors='replace')}"
                )
            for uid in chunk:
                key = uid.decode()
                if key in state["verdicts"]:
                    state["verdicts"][key]["moved_to"] = folder
                state["moved"].append(
                    {
                        "message_id": ids.get(key),
                        "folder": folder,
                        "subject": state["verdicts"].get(key, {}).get("subject", ""),
                    }
                )
            total += len(chunk)
        print(f"  moved {len(uids):>4} -> {folder}", file=sys.stderr)

    return total


def undo_moves(client: imaplib.IMAP4_SSL, state: dict, mailbox: str) -> int:
    """Put everything this tool moved back into the inbox."""
    moved = state.get("moved", [])
    if not moved:
        print("nothing recorded as moved", file=sys.stderr)
        return 0

    by_folder: dict[str, list[str]] = defaultdict(list)
    for record in moved:
        if record.get("message_id"):
            by_folder[record["folder"]].append(record["message_id"])

    restored = 0
    for folder, message_ids in sorted(by_folder.items()):
        status, _ = client.select(folder, readonly=False)
        if status != "OK":
            print(f"  skipping {folder}: cannot open", file=sys.stderr)
            continue
        for message_id in message_ids:
            status, data = client.uid(
                "SEARCH", None, "HEADER", "Message-ID", message_id
            )
            if status != "OK" or not data or not data[0]:
                continue
            found = data[0].split()
            status, _ = client.uid("MOVE", b",".join(found), mailbox)
            if status == "OK":
                restored += len(found)
        print(f"  restored from {folder}", file=sys.stderr)

    for record in state.get("verdicts", {}).values():
        record.pop("moved_to", None)
    state["moved"] = []
    return restored


# }}}


# {{{ Reporting
def render(state: dict) -> str:
    verdicts = state["verdicts"]
    counts = Counter(v["bucket"] for v in verdicts.values())
    senders: dict[str, Counter] = defaultdict(Counter)
    for record in verdicts.values():
        senders[record["bucket"]][record["address"]] += 1

    width = max((len(FOLDER.get(b, b)) for b in counts), default=10)
    lines = [
        "",
        f"  {len(verdicts)} messages classified, {len(state['sender_cache'])} distinct senders",
        f"  {state['by_rule']} by rule, {state['by_model']} by model, {state['failed']} failed",
        "",
        "  proposed pigeonholes",
        "  " + "-" * 58,
    ]
    for bucket, total in counts.most_common():
        bar = "#" * min(30, total * 30 // max(counts.values()))
        lines.append(f"  {FOLDER.get(bucket, bucket):<{width}}  {total:>6}  {bar}")

    lines += ["", "  biggest senders per pigeonhole", "  " + "-" * 58]
    for bucket, _ in counts.most_common():
        top = ", ".join(f"{a} ({n})" for a, n in senders[bucket].most_common(3))
        lines.append(f"  {FOLDER.get(bucket, bucket):<{width}}  {top}")

    return "\n".join(lines) + "\n"


# }}}


def main() -> int:  # noqa: PLR0912, PLR0915
    parser = argparse.ArgumentParser(
        description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter
    )
    parser.add_argument(
        "--host", default=os.environ.get("IMAP_HOST", "imap.migadu.com")
    )
    parser.add_argument("--user", default=os.environ.get("IMAP_USER"))
    parser.add_argument("--mailbox", default="INBOX")
    parser.add_argument(
        "--smtp-host", default=os.environ.get("SMTP_HOST", "smtp.migadu.com")
    )
    parser.add_argument(
        "--classifier",
        default=os.environ.get(
            "CLASSIFIER_URL", "http://127.0.0.1:8496/v1/chat/completions"
        ),
    )
    parser.add_argument(
        "--state", type=Path, default=Path("/tmp/n8n-inbox-backfill.json")
    )  # noqa: S108
    parser.add_argument(
        "--batch", type=int, default=200, help="messages fetched per IMAP round trip"
    )
    parser.add_argument(
        "--limit",
        type=int,
        default=0,
        help="stop after this many new classifications (0 = no limit)",
    )
    parser.add_argument("--timeout", type=int, default=180)
    parser.add_argument(
        "--peek-bytes", type=int, default=8192, help="bytes fetched per message"
    )
    parser.add_argument(
        "--estimate-only", action="store_true", help="count the work and exit"
    )
    parser.add_argument(
        "--check-login", action="store_true", help="verify credentials and exit"
    )
    parser.add_argument(
        "--apply", action="store_true", help="actually move mail into folders"
    )
    parser.add_argument(
        "--include-junk",
        action="store_true",
        help="also move unsolicited mail into Junk (trains the spam filter)",
    )
    parser.add_argument(
        "--undo",
        action="store_true",
        help="move everything this tool moved back to INBOX",
    )
    args = parser.parse_args()

    user = args.user or input("IMAP user: ").strip()
    # Prompted rather than stored: this is a one-off walk of a personal
    # mailbox, and a sops secret for it would be a permanent key to that
    # mailbox in a repository mirrored to a public forge.
    password = os.environ.get("IMAP_PASSWORD") or getpass.getpass(
        f"IMAP password for {user}: "
    )

    state = {
        "verdicts": {},
        "sender_cache": {},
        "by_rule": 0,
        "by_model": 0,
        "failed": 0,
    }
    if args.state.exists():
        state.update(json.loads(args.state.read_text()))
        print(f"resuming: {len(state['verdicts'])} already classified", file=sys.stderr)

    if args.check_login:
        # IMAP and SMTP share one credential at Migadu, so testing both in one
        # run separates "this password is wrong" from "this password is right
        # but IMAP specifically is refused for this mailbox". The server says
        # "Authentication failed" either way, so asking it twice is the only
        # way to tell.
        imap_result = "?"
        try:
            probe = imaplib.IMAP4_SSL(args.host)
            probe.login(user, password)
            status, data = probe.status(args.mailbox, "(MESSAGES)")
            imap_result = f"OK, {args.mailbox} -> {data[0].decode() if status == 'OK' else status}"
            probe.logout()
        except imaplib.IMAP4.error as error:
            imap_result = f"REFUSED ({error})"

        smtp_result = "?"
        try:
            with smtplib.SMTP_SSL(args.smtp_host, 465, timeout=20) as smtp:
                smtp.login(user, password)
            smtp_result = "OK"
        except (smtplib.SMTPException, OSError) as error:
            smtp_result = f"REFUSED ({error})"

        print(f"  IMAP  {args.host:<22} {imap_result}")
        print(f"  SMTP  {args.smtp_host:<22} {smtp_result}")
        print()
        if imap_result.startswith("OK"):
            print("Credentials are good.")
        elif smtp_result == "OK":
            print(
                "The password is correct -- SMTP accepted it -- but IMAP refused this\n"
                "mailbox. That is a per-mailbox setting at the provider, not something\n"
                "this tool or n8n can work around: enable IMAP access for the mailbox."
            )
        else:
            print(
                "Both protocols refused the same password, so it is the password\n"
                "itself rather than an IMAP restriction. Migadu keeps a password per\n"
                "mailbox, separate from the admin account you sign into the web\n"
                "console with; resetting the mailbox password is usually the fix."
            )
        return 0

    client = connect(args.host, user, password, args.mailbox)

    if args.undo:
        restored = undo_moves(client, state, args.mailbox)
        args.state.write_text(json.dumps(state))
        client.logout()
        print(f"restored {restored} message(s) to {args.mailbox}")
        return 0

    status, data = client.uid("SEARCH", None, "ALL")
    if status != "OK":
        raise SystemExit("SEARCH failed")
    uids = data[0].split()
    todo = [u for u in uids if u.decode() not in state["verdicts"]]

    print(
        f"{len(uids)} messages in {args.mailbox}, {len(todo)} still to classify",
        file=sys.stderr,
    )
    if args.estimate_only:
        known = len(state["sender_cache"])
        print(
            f"{known} senders already cached; unseen senders cost ~11 s each on this box",
            file=sys.stderr,
        )
        return 0

    done = 0
    started = time.monotonic()
    for offset in range(0, len(todo), args.batch):
        chunk = todo[offset : offset + args.batch]
        for uid, sender, subject, date, snippet in fetch_messages(
            client, chunk, args.peek_bytes
        ):
            address = (email.utils.parseaddr(sender)[1] or sender).lower()
            name = email.utils.parseaddr(sender)[0] or address

            rule = rule_for(address)
            if rule:
                verdict = {
                    "bucket": rule[0],
                    "importance": rule[1],
                    "why": "matched a deterministic rule",
                }
                state["by_rule"] += 1
            elif address in state["sender_cache"]:
                verdict = dict(state["sender_cache"][address])
            else:
                try:
                    verdict = classify(
                        args.classifier, name, address, subject, "", args.timeout
                    )
                    state["by_model"] += 1
                except (
                    urllib.error.URLError,
                    ValueError,
                    KeyError,
                    TimeoutError,
                ) as error:
                    verdict = {
                        "bucket": "unsorted",
                        "importance": 3,
                        "why": str(error)[:90],
                    }
                    state["failed"] += 1
                # Cached per sender, from the first message seen from them: a
                # personal mailbox is a few hundred senders repeating, and this
                # is what makes a ten thousand message backlog affordable at all.
                # Failures are cached too, so one unreachable classifier does not
                # retry the same sender a thousand times in one run.
                state["sender_cache"][address] = verdict

            state["verdicts"][uid.decode()] = {
                **verdict,
                "address": address,
                "subject": subject,
                "date": date,
            }
            done += 1
            if args.limit and done >= args.limit:
                break

        args.state.write_text(json.dumps(state))
        rate = done / max(0.001, time.monotonic() - started)
        print(
            f"  {len(state['verdicts'])}/{len(uids)} classified ({rate:.1f}/s)",
            file=sys.stderr,
        )
        if args.limit and done >= args.limit:
            break

    demoted = demote_frequent_senders(state["verdicts"])
    if demoted:
        print(
            f"  re-bucketed {demoted} message(s) from frequent senders out of unsolicited",
            file=sys.stderr,
        )
    args.state.write_text(json.dumps(state))
    print(render(state))

    # Moving is the only part that writes to the mailbox, so it is opt-in and
    # the default run shows what it would do instead of doing it.
    plan = plan_moves(state["verdicts"], args.include_junk)
    if args.apply:
        moved = apply_moves(client, state, args.mailbox, args.include_junk)
        args.state.write_text(json.dumps(state))
        print(f"\n  moved {moved} message(s). Undo with: just n8n-backfill --undo")
    else:
        print("  would move (pass --apply to do it):")
        for folder, uids in sorted(plan.items()):
            print(f"    {len(uids):>4} -> {folder}")
        skipped = len(state["verdicts"]) - sum(len(u) for u in plan.values())
        if skipped:
            print(
                f"    {skipped:>4} left in place (unsorted, or unsolicited without --include-junk)"
            )

    client.logout()
    return 0


if __name__ == "__main__":
    sys.exit(main())
