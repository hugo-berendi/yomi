import hashlib
import contextlib
from datetime import timezone
import io
from http.client import HTTPConnection
import json
import os
from pathlib import Path
import subprocess
import tempfile
import threading
from types import SimpleNamespace
import unittest
import urllib.error
from unittest.mock import patch

import classifier
import worker


CERT = b"synthetic-bridge-certificate"


def configuration(apply=False):
    return {
        "apply": apply,
        "maxMessages": 50,
        "maxReadMessages": 1000,
        "markExistingRead": True,
        "labelExisting": True,
        "maxLabelMessages": 50,
        "keepFolders": [],
        "bridgeHost": "127.0.0.1",
        "bridgePort": 1143,
        "bridgeCertificateSha256": hashlib.sha256(CERT).hexdigest(),
        "modelUrl": "http://127.0.0.1:8496",
        "opExecutable": "/test/op",
        "usernameRef": "op://Automation/Bridge/username",
        "passwordRef": "op://Automation/Bridge/password",
        "apiTokenRef": "op://Automation/Sorter/api-token",
    }


def V(folder, action=False, tax=False):
    """A classifier verdict."""
    return {"folder": folder, "action": action, "tax": tax}


HEADERS = {
    "Message-ID": "<synthetic@example.invalid>",
    "Date": "Mon, 05 Oct 2026 10:00:00 +0200",
}


class FakeObj:
    """Just enough of email.message.Message for fingerprints and headers."""

    def __init__(self, data, headers):
        self.data, self.headers = data, headers

    def as_bytes(self):
        return self.data

    def get(self, name, default=None):
        return self.headers.get(name, default)

    def keys(self):
        return list(self.headers)

    def get_all(self, name):
        value = self.headers.get(name)
        return [value] if value else None


class FakeSecrets:
    def get(self, field):
        return "x" * 40 if field == "apiTokenRef" else "synthetic"


class Mailbox:
    def __init__(
        self,
        missing=False,
        changed=False,
        invalid_uid=False,
        no_move=False,
        certificate=CERT,
        store_fail=False,
        headers=None,
        extra_folders=(),
        empty=(),
        ki_messages=False,
    ):
        self.empty, self.ki_messages = set(empty), ki_messages
        self.deleted = []
        self.headers = HEADERS if headers is None else headers
        self.current = None
        self.queries = []
        self.commands = []
        self.created = []
        self.logged_out = False
        self.status_calls = 0
        self.missing, self.changed, self.invalid_uid, self.store_fail = (
            missing,
            changed,
            invalid_uid,
            store_fail,
        )
        self.names = [
            "INBOX",
            "Archive",
            "Sent",
            "Drafts",
            "Spam",
            "Trash",
            "All Mail",
            "Labels/Test",
            "Folders/Unknown",
            "Folders/Werbung/Sub",
            *extra_folders,
        ]
        self.names += [
            "Folders/" + prefix + category
            for prefix in ("", "KI-")
            for category in classifier.CATEGORIES
        ]
        self.folder = SimpleNamespace(
            list=lambda: [
                SimpleNamespace(name=n, delim="/", flags=()) for n in self.names
            ],
            set=self.select,
            status=self.status,
            create=self.created.append,
            delete=self.deleted.append,
        )
        self.client = SimpleNamespace(
            socket=lambda: SimpleNamespace(getpeercert=lambda **kw: certificate),
            capability=lambda: ("OK", [b"IMAP4rev1" if no_move else b"IMAP4rev1 MOVE"]),
            uid=self.uid,
        )

    def select(self, name):
        self.current = name

    def status(self, folder, items):
        if items == ["MESSAGES"]:
            return {"MESSAGES": 0 if folder in self.empty else 1}
        self.status_calls += 1
        return {"UIDVALIDITY": 8 if self.invalid_uid and self.status_calls > 2 else 7}

    def login(self, username, password, **kwargs):
        assert username == password == "synthetic"

    def logout(self):
        self.logged_out = True

    def fetch(self, query, **kwargs):
        assert kwargs["mark_seen"] is False
        self.queries.append((self.current, query, kwargs))
        if self.missing and query.startswith("UID "):
            return iter([])
        data = (
            b"changed"
            if self.changed and query.startswith("UID ")
            else b"synthetic-message"
        )
        return iter(
            [
                SimpleNamespace(
                    uid="1",
                    subject="Synthetic mail",
                    text="Synthetic body",
                    html="",
                    from_="sender@example.invalid",
                    obj=FakeObj(data, self.headers),
                )
            ]
        )

    def uids(self, criteria):
        assert criteria == "ALL"
        if self.current.startswith("Folders/KI-") and not self.ki_messages:
            return []
        return ["1"]

    def uid(self, *args):
        assert args[0] in ("STORE", "MOVE", "COPY")
        if args[0] == "STORE":
            assert args[1:] == ("1", "+FLAGS.SILENT", "(\\Seen)")
        self.commands.append((self.current, args))
        return ("NO", []) if self.store_fail and args[0] == "STORE" else ("OK", [])


class WorkerTests(unittest.TestCase):
    def test_enforced_rules_override_the_model(self):
        from datetime import datetime as dt
        from email.utils import format_datetime

        recent = format_datetime(dt.now(timezone.utc))
        old = "Mon, 28 Jan 2019 10:00:00 +0100"
        cases = [
            # A long-expired deadline is never Action; a 2019 "confirm by
            # 03.02.2019" came back urgent from the model.
            (V("Rechnungen", True, True), old, V("Rechnungen", False, True)),
            (V("Rechnungen", True, True), recent, V("Rechnungen", True, True)),
            # Without a readable date the model's Action stands.
            (V("Termine", True), "not a date", V("Termine", True)),
            (V("Werbung", True, True), recent, V("Werbung")),
            (V("Newsletter", True, True), recent, V("Newsletter")),
            (V("Konten-Sicherheit", True, True), recent, V("Konten-Sicherheit")),
        ]
        for answer, date, expected in cases:
            with self.subTest(answer=answer, date=date):
                msg = SimpleNamespace(
                    obj=FakeObj(b"", {"Date": date}),
                    text="",
                    html="",
                    from_="a@example.org",
                    subject="s",
                )
                with patch.object(classifier, "ask", return_value=answer):
                    self.assertEqual(classifier.classify(msg), expected)

    def test_labels_from_verdict_mail_year_and_alias(self):
        def msg(headers):
            return SimpleNamespace(obj=FakeObj(b"", headers))

        dated = {"Date": "Tue, 30 Dec 2025 22:00:00 +0100"}
        self.assertEqual(
            classifier.labels_for(msg(dated), V("Rechnungen", True, True)),
            ["Action", "Steuer 2025"],
        )
        # The year follows the mail, not the day it is sorted.
        self.assertEqual(
            classifier.labels_for(
                msg({"Date": "Thu, 01 Jan 2026 00:30:00 +0100"}),
                V("Rechnungen", tax=True),
            ),
            ["Steuer 2026"],
        )
        # No date, no year to file it under.
        self.assertEqual(classifier.labels_for(msg({}), V("Rechnungen", tax=True)), [])
        for alias in (
            {"X-SimpleLogin-Type": "Forward"},
            {"To": "shop.x1@yokai.hugo-berendi.de"},
            {"Delivered-To": "Name <a@YOKAI.hugo-berendi.de>"},
        ):
            with self.subTest(alias=alias):
                self.assertEqual(
                    classifier.labels_for(msg(alias), V("Werbung")), ["Alias"]
                )
        for plain in (
            {"To": "personal@hugo-berendi.de"},
            {"To": "x@yokai.example.org"},
        ):
            with self.subTest(plain=plain):
                self.assertEqual(classifier.labels_for(msg(plain), V("Werbung")), [])

    def test_oversized_prompt_is_shortened_not_fatal(self):
        # A mail whose body tokenizes past the classifier's context (seen
        # 2026-10-28: 12519 tokens against 8192) failed every run with an
        # HTTPError. It must be shortened, and held if it never fits.
        msg = SimpleNamespace(
            text="\U0001f600" * 6000, html="", from_="a@example.org", subject="Big"
        )
        sizes = []

        def opener(limit, status=400):
            def open_request(request, **kwargs):
                body = json.loads(json.loads(request.data)["messages"][1]["content"])[
                    "body"
                ]
                sizes.append(len(body))
                if len(body) > limit:
                    raise urllib.error.HTTPError(
                        request.full_url,
                        status,
                        "Bad Request",
                        {},
                        io.BytesIO(
                            b'{"error":{"message":"request (12519 tokens) exceeds the available context size (8192 tokens), try increasing it"}}'
                        ),
                    )
                return io.BytesIO(
                    json.dumps(
                        {
                            "choices": [
                                {"message": {"content": json.dumps(V("Newsletter"))}}
                            ]
                        }
                    ).encode()
                )

            return SimpleNamespace(open=open_request)

        with (
            patch.object(classifier, "ZoneInfo", return_value=timezone.utc),
            patch.object(
                classifier.urllib.request, "build_opener", return_value=opener(1600)
            ),
        ):
            self.assertEqual(classifier.classify(msg), V("Newsletter"))
        self.assertEqual(sizes, [6000, 3000, 1500])

        with (
            patch.object(classifier, "ZoneInfo", return_value=timezone.utc),
            patch.object(
                classifier.urllib.request, "build_opener", return_value=opener(0)
            ),
        ):
            with self.assertRaises(ValueError):
                classifier.classify(msg)

        # Any other HTTP error is the model server's problem and still aborts.
        with (
            patch.object(classifier, "ZoneInfo", return_value=timezone.utc),
            patch.object(
                classifier.urllib.request,
                "build_opener",
                return_value=opener(0, status=500),
            ),
        ):
            with self.assertRaises(urllib.error.HTTPError):
                classifier.classify(msg)

    def test_local_classifier_schema_and_twitch_boundary(self):
        msg = SimpleNamespace(
            text="Schau jetzt auf Twitch zu",
            html="",
            from_="no-reply@twitch.tv",
            subject="LexoLeni ist live: Einmal Ente suess sauer",
        )
        with (
            patch.object(classifier, "ZoneInfo", return_value=timezone.utc),
            patch.object(
                classifier.urllib.request,
                "build_opener",
                side_effect=AssertionError("Twitch must bypass the model"),
            ),
        ):
            self.assertEqual(classifier.classify(msg), V("Werbung"))
        msg.from_ = "no-reply@twitch.tv.attacker.invalid"
        requests = []

        def open_request(request, **kwargs):
            requests.append(json.loads(request.data))
            return io.BytesIO(
                json.dumps(
                    {"choices": [{"message": {"content": json.dumps(V("Newsletter"))}}]}
                ).encode()
            )

        with (
            patch.object(classifier, "ZoneInfo", return_value=timezone.utc),
            patch.object(
                classifier.urllib.request,
                "build_opener",
                return_value=SimpleNamespace(open=open_request),
            ),
        ):
            self.assertEqual(classifier.classify(msg), V("Newsletter"))
        self.assertEqual(requests[0]["model"], "qwen3.5:9b")
        self.assertEqual(
            requests[0]["response_format"]["json_schema"]["schema"]["properties"][
                "folder"
            ]["enum"],
            classifier.CATEGORIES,
        )
        schema = requests[0]["response_format"]["json_schema"]["schema"]
        self.assertFalse(schema["additionalProperties"])
        self.assertEqual(schema["required"], ["folder", "action", "tax"])
        self.assertEqual(schema["properties"]["action"], {"type": "boolean"})

    def test_config_and_schema(self):
        self.assertEqual(len(classifier.CATEGORIES), 12)
        self.assertNotIn("Wichtig", classifier.CATEGORIES)
        self.assertEqual(classifier.MODEL, "qwen3.5:9b")
        worker.validate_config(configuration())
        for changes in (
            {"bridgeCertificateSha256": ""},
            {"passwordRef": "plaintext"},
            {"maxMessages": True},
            {"bridgePort": 0},
            {"modelUrl": "https://user:secret@host"},
            {"labelExisting": "yes"},
            {"maxLabelMessages": 0},
            {"keepFolders": "Projekte"},
            {"keepFolders": ["a/b"]},
        ):
            with self.assertRaises(ValueError):
                worker.validate_config({**configuration(), **changes})

    def test_pin_from_pem_matches_the_der_the_connection_checks(self):
        import ssl

        der = b"0\x03\x02\x01\x00"  # any bytes: the pin is a hash of DER, not a parse
        with tempfile.TemporaryDirectory() as directory:
            pem = Path(directory, "bridge.pem")
            pem.write_text(ssl.DER_cert_to_PEM_cert(der), encoding="ascii")
            config = worker.validate_config(
                {
                    **configuration(),
                    "bridgeCertificateSha256": "0" * 64,
                    "bridgeCertificateFile": str(pem),
                }
            )
        self.assertEqual(
            config["bridgeCertificateSha256"], hashlib.sha256(der).hexdigest()
        )

    def run_sorter(
        self,
        box,
        state,
        apply=False,
        mark_read=False,
        verdict="Rechnungen",
        max_messages=50,
        labels=False,
        run_id="test-run",
    ):
        config = {**configuration(apply), "maxMessages": max_messages}
        sorter = worker.Sorter(
            config, FakeSecrets(), Path(state), lambda *args, **kwargs: box
        )
        if isinstance(verdict, str) and verdict in classifier.CATEGORIES:
            verdict = V(verdict)
        with patch.object(classifier, "classify", return_value=verdict) as classify:
            result = sorter.run(run_id, mark_read, labels=labels)
        return result, classify.call_count

    def test_run_calls_the_openai_compatible_endpoint(self):
        # The worker, not the classifier default, decides the URL. It once
        # kept Ollama's /api/chat after the move to llama.cpp, and every run
        # failed with a 404 while the classifier tests stayed green.
        seen = []
        with tempfile.TemporaryDirectory() as state:
            sorter = worker.Sorter(
                configuration(), FakeSecrets(), Path(state), lambda *a, **kw: Mailbox()
            )

            def classify(_msg):
                seen.append(classifier.MODEL_CHAT_URL)
                return V("Rechnungen")

            with patch.object(classifier, "classify", side_effect=classify):
                sorter.run("url")
        self.assertEqual(set(seen), {"http://127.0.0.1:8496/v1/chat/completions"})

    def test_dry_run_only_inbox_archive_and_cache(self):
        with tempfile.TemporaryDirectory() as state:
            box = Mailbox()
            result, calls = self.run_sorter(box, state)
            self.assertEqual(result["planned"], 2)
            self.assertEqual(calls, 2)
            self.assertEqual({q[0] for q in box.queries}, {"INBOX", "Archive"})
            self.assertFalse(box.commands or box.created)
            self.assertTrue(box.logged_out)
            sorter = worker.Sorter(
                configuration(), FakeSecrets(), Path(state), lambda *a, **kw: Mailbox()
            )
            with patch.object(
                classifier,
                "classify",
                side_effect=AssertionError("Cached mail must not call the model"),
            ):
                sorter.run("second-run")

    def test_store_before_move(self):
        with tempfile.TemporaryDirectory() as state:
            box = Mailbox()
            result, _ = self.run_sorter(box, state, apply=True)
            self.assertEqual(result["moved"], 2)
            self.assertEqual(result["markedRead"], 2)
            self.assertEqual(
                [c[1][0] for c in box.commands], ["STORE", "MOVE", "STORE", "MOVE"]
            )
            rows = [
                json.loads(line)
                for line in (Path(state) / "actions-test-run.jsonl")
                .read_text(encoding="utf-8")
                .splitlines()
            ]
            self.assertEqual([row["status"] for row in rows], ["pending", "done"] * 4)

    def test_action_label_keeps_unread_and_is_set_before_the_move(self):
        with tempfile.TemporaryDirectory() as state:
            box = Mailbox()
            result, calls = self.run_sorter(
                box,
                state,
                apply=True,
                verdict=V("Rechnungen", action=True, tax=True),
                max_messages=1,
            )
            self.assertEqual((result["moved"], result["labelled"], calls), (1, 2, 1))
            self.assertEqual(result["markedRead"], 0)
            self.assertEqual(
                [c[1] for c in box.commands],
                [
                    ("COPY", "1", worker.encode_folder("Labels/Action")),
                    ("COPY", "1", worker.encode_folder("Labels/Steuer 2026")),
                    ("MOVE", "1", worker.encode_folder("Folders/Rechnungen")),
                ],
            )
            self.assertEqual(
                sorted(box.created), ["Labels/Action", "Labels/Steuer 2026"]
            )

    def test_legacy_wichtig_folders_are_sorted_again(self):
        with tempfile.TemporaryDirectory() as state:
            box = Mailbox(extra_folders=("Folders/Wichtig", "Folders/KI-Wichtig"))
            result, _ = self.run_sorter(box, state)
            self.assertEqual(result["planned"], 4)
            # Wichtig first, so its Action labels are not starved by a backlog.
            self.assertEqual(
                [q[0] for q in box.queries],
                ["Folders/Wichtig", "Folders/KI-Wichtig", "INBOX", "Archive"],
            )

    def test_tidy_merges_ki_folders_and_deletes_empty_unused_ones(self):
        with tempfile.TemporaryDirectory() as state:
            box = Mailbox(
                ki_messages=True,
                extra_folders=("Folders/Personal", "Folders/Projekte", "Labels/Leer"),
                empty={
                    "Folders/Personal",
                    "Folders/Projekte",
                    "Folders/Werbung/Sub",
                    "Folders/Unknown",
                    "Folders/Rechnungen",
                    "Labels/Leer",
                }
                | {"Folders/KI-" + c for c in classifier.CATEGORIES},
            )
            config = {**configuration(True), "keepFolders": ["Projekte"]}
            sorter = worker.Sorter(
                config, FakeSecrets(), Path(state), lambda *a, **kw: box
            )
            with patch.object(classifier, "classify", return_value=V("Rechnungen")):
                result = sorter.run("tidy")
            merges = [c for c in box.commands if c[0].startswith("Folders/KI-")]
            self.assertEqual(len(merges), len(classifier.CATEGORIES))
            self.assertIn(
                (
                    "Folders/KI-Rechnungen",
                    ("MOVE", "1", worker.encode_folder("Folders/Rechnungen")),
                ),
                merges,
            )
            # Empty and unused go; categories, kept names and labels stay.
            self.assertEqual(
                set(box.deleted),
                {"Folders/Personal", "Folders/Werbung/Sub", "Folders/Unknown"}
                | {"Folders/KI-" + c for c in classifier.CATEGORIES},
            )
            self.assertEqual(result["tidy"]["merged"], len(classifier.CATEGORIES))
            self.assertEqual(result["sources"], {"INBOX": 1, "Archive": 1})
            log = Path(state, "actions-tidy.jsonl").read_text()
            self.assertIn('"delete_folder"', log)

    def test_tidy_in_a_dry_run_only_reports(self):
        with tempfile.TemporaryDirectory() as state:
            box = Mailbox(
                ki_messages=True,
                extra_folders=("Folders/Personal",),
                empty={"Folders/Personal"},
            )
            result, _ = self.run_sorter(box, state)
            self.assertEqual(result["tidy"]["deletedFolders"], ["Folders/Personal"])
            self.assertEqual(result["tidy"]["merged"], len(classifier.CATEGORIES))
            self.assertFalse(box.deleted or box.commands or box.created)

    def test_read_pass_leaves_action_labelled_mail_unread(self):
        with tempfile.TemporaryDirectory() as state:
            box = Mailbox(no_move=True, extra_folders=("Labels/Action",))
            result, _ = self.run_sorter(box, state, apply=True, mark_read=True)
            # Every fake message shares the Message-ID found under Action.
            self.assertEqual(result["markedRead"], 0)
            self.assertFalse(box.commands)

    def test_label_pass_labels_old_mail_once(self):
        alias = {**HEADERS, "X-SimpleLogin-Type": "Forward"}
        with tempfile.TemporaryDirectory() as state:
            box = Mailbox(no_move=True, headers=alias, ki_messages=True)
            result, calls = self.run_sorter(
                box, state, apply=True, labels=True, verdict=V("Rechnungen", tax=True)
            )
            folders = 2 * len(classifier.CATEGORIES)
            # Werbung, Newsletter and Konten-Sicherheit, current and KI-, are
            # labelled without the model.
            self.assertEqual(calls, folders - 6)
            self.assertEqual(result["planned"], folders)
            self.assertEqual(result["moved"] + result["markedRead"], 0)
            copies = [c[1][2] for c in box.commands]
            self.assertEqual(
                copies.count(worker.encode_folder("Labels/Alias")), folders
            )
            self.assertEqual(
                copies.count(worker.encode_folder("Labels/Steuer 2026")), folders - 6
            )
            self.assertTrue(all(c[1][0] == "COPY" for c in box.commands))
            self.assertTrue(
                all(q[1] == "UID 1" for q in box.queries if q[0].startswith("Folders/"))
            )
            again = Mailbox(no_move=True, headers=alias, ki_messages=True)
            result, calls = self.run_sorter(
                again, state, apply=True, labels=True, run_id="again"
            )
            self.assertEqual((result["planned"], calls), (0, 0))
            self.assertFalse(again.commands)

    def test_label_pass_dry_run_records_nothing(self):
        with tempfile.TemporaryDirectory() as state:
            self.run_sorter(Mailbox(no_move=True, ki_messages=True), state, labels=True)
            result, _ = self.run_sorter(
                Mailbox(no_move=True, ki_messages=True),
                state,
                labels=True,
                run_id="again",
            )
            self.assertEqual(result["planned"], 2 * len(classifier.CATEGORIES))

    def test_label_pass_runs_only_when_nothing_was_sorted(self):
        for sorted_now, expected in ((0, True), (3, False)):
            with (
                self.subTest(sorted_now=sorted_now),
                tempfile.TemporaryDirectory() as state,
            ):
                app = worker.Application(configuration(True), Path(state))
                calls = []

                def run(run_id, mark_read=False, labels=False):
                    calls.append(
                        ("read" if mark_read else "labels" if labels else "sort")
                    )
                    planned = sorted_now if not (mark_read or labels) else 0
                    return {"planned": planned, "unclassified": 0}

                app.sorter.run = run
                app.lock.acquire()
                app.finish({"id": "t", "status": "running"}, False)
                self.assertEqual("labels" in calls, expected)

    def test_retroactive_reads_only_category_unseen_headers_without_ai(self):
        with tempfile.TemporaryDirectory() as state:
            box = Mailbox(no_move=True)
            result, calls = self.run_sorter(box, state, apply=True, mark_read=True)
            self.assertEqual(calls, 0)
            self.assertEqual(result["markedRead"], 2 * len(classifier.CATEGORIES))
            self.assertEqual(result["moved"], 0)
            self.assertTrue(all(c[1][0] == "STORE" for c in box.commands))
            self.assertTrue(all(q[2]["headers_only"] for q in box.queries))
            self.assertTrue(
                all(q[1] == "UNSEEN" or q[1] == "UID 1" for q in box.queries)
            )
            self.assertFalse(
                any(
                    q[0]
                    in (
                        "INBOX",
                        "Archive",
                        "Folders/Wichtig",
                        "Folders/KI-Wichtig",
                        "Folders/Unknown",
                        "Folders/Werbung/Sub",
                    )
                    for q in box.queries
                )
            )

    def test_changed_or_missing_is_held_without_mutation(self):
        for changes in ({"missing": True}, {"changed": True}):
            with self.subTest(changes=changes), tempfile.TemporaryDirectory() as state:
                box = Mailbox(**changes)
                result, _ = self.run_sorter(box, state, apply=True)
                self.assertEqual(result["held"], 2)
                self.assertFalse(box.commands)

    def test_certificate_guard_and_native_move(self):
        for changes in (
            {"certificate": b"wrong"},
            {"no_move": True},
            {"invalid_uid": True},
        ):
            with self.subTest(changes=changes), tempfile.TemporaryDirectory() as state:
                box = Mailbox(**changes)
                with self.assertRaises(RuntimeError):
                    self.run_sorter(box, state, apply=True)
                self.assertFalse(box.commands)
                self.assertTrue(box.logged_out)

    def test_read_flag_failure(self):
        with tempfile.TemporaryDirectory() as state:
            box = Mailbox(store_fail=True)
            with self.assertRaises(RuntimeError):
                self.run_sorter(box, state, apply=True)
            self.assertFalse(any(c[1][0] == "MOVE" for c in box.commands))
            self.assertTrue(box.logged_out)

    def test_unusable_model_answer_holds_only_that_message(self):
        # INBOX gets an invented label, Archive a valid one: the first stays
        # untouched, the second is still filed, and the failure is cached.
        for unusable in ("invented", ValueError("not JSON"), KeyError("message")):
            with (
                self.subTest(unusable=repr(unusable)),
                tempfile.TemporaryDirectory() as state,
            ):
                box = Mailbox()
                sorter = worker.Sorter(
                    configuration(True),
                    FakeSecrets(),
                    Path(state),
                    lambda *a, **kw: box,
                )
                with patch.object(
                    classifier, "classify", side_effect=[unusable, V("Rechnungen")]
                ):
                    result = sorter.run("partial")
                self.assertEqual((result["unclassified"], result["moved"]), (1, 1))
                self.assertEqual([c[0] for c in box.commands], ["Archive", "Archive"])
                held = [
                    json.loads(line)
                    for line in Path(state, "plan-partial.jsonl")
                    .read_text()
                    .splitlines()
                ]
                self.assertEqual(held[0]["status"], "model_answer_unusable")
                with patch.object(classifier, "classify") as again:
                    sorter.run("partial-again")
                self.assertEqual(again.call_count, 0)

    def test_held_messages_count_against_the_budget(self):
        with tempfile.TemporaryDirectory() as state:
            box = Mailbox()
            result, calls = self.run_sorter(
                box, state, verdict="invented", max_messages=1
            )
            self.assertEqual((result["unclassified"], calls), (1, 1))

    def test_classifier_failure_preserves_mail(self):
        with tempfile.TemporaryDirectory() as state:
            box = Mailbox()
            sorter = worker.Sorter(
                configuration(True), FakeSecrets(), Path(state), lambda *a, **kw: box
            )
            with (
                patch.object(
                    classifier, "classify", side_effect=RuntimeError("Model offline")
                ),
                self.assertRaises(RuntimeError),
            ):
                sorter.run("offline")
            self.assertFalse(box.commands)
            self.assertTrue(box.logged_out)

    def test_service_account_read_capture_cache_and_no_leaks(self):
        with (
            tempfile.TemporaryDirectory() as directory,
            patch.dict(os.environ, {"CREDENTIALS_DIRECTORY": directory}),
        ):
            Path(directory, "op-service-account").write_text(
                "test-bootstrap-token", encoding="utf-8"
            )
            secrets = worker.Secrets(configuration())
            with patch.object(
                worker.subprocess,
                "run",
                return_value=SimpleNamespace(
                    returncode=0, stdout="test-password", stderr=""
                ),
            ) as run:
                self.assertEqual(secrets.get("passwordRef"), "test-password")
                self.assertEqual(secrets.get("passwordRef"), "test-password")
                self.assertEqual(run.call_count, 1)
                args, kwargs = run.call_args
                self.assertNotIn("test-password", str(args))
                self.assertNotIn("test-bootstrap-token", str(args))
                self.assertEqual(kwargs["env"]["OP_BIOMETRIC_UNLOCK_ENABLED"], "false")
                self.assertTrue(kwargs["capture_output"])
            secrets = worker.Secrets(configuration())
            with patch.object(
                worker.subprocess,
                "run",
                side_effect=subprocess.TimeoutExpired(
                    ["op"], 1, output="test-password"
                ),
            ):
                with self.assertRaisesRegex(RuntimeError, "^1Password read failed$"):
                    secrets.get("passwordRef")

    def test_http_auth_and_fixed_routes(self):
        app = SimpleNamespace(
            secrets=FakeSecrets(),
            previous={"status": "done"},
            start=lambda read: {"started": True, "markRead": read},
        )
        server = worker.ThreadingHTTPServer(("127.0.0.1", 0), worker.Handler)
        server.application = app
        thread = threading.Thread(target=server.serve_forever, daemon=True)
        thread.start()
        try:
            for path, token, body, expected in (
                ("/api/tick", "wrong", None, 401),
                ("/api/tick", "x" * 40, None, 202),
                ("/api/mark-read", "x" * 40, None, 202),
                ("/api/tick", "x" * 40, '{"apply":true}', 400),
                ("/untrusted", "x" * 40, None, 404),
            ):
                connection = HTTPConnection("127.0.0.1", server.server_port, timeout=5)
                connection.request(
                    "POST",
                    path,
                    body=body,
                    headers={"Authorization": "Bearer " + token},
                )
                response = connection.getresponse()
                self.assertEqual(response.status, expected)
                response.read()
                connection.close()
        finally:
            server.shutdown()
            server.server_close()
            thread.join()

    def test_overlap_rejected_and_restart_reported(self):
        with tempfile.TemporaryDirectory() as state:
            worker.atomic_json(
                Path(state) / "status.json", {"id": "previous", "status": "running"}
            )
            app = worker.Application(configuration(), Path(state))
            self.assertEqual(app.previous["status"], "failed")
            app.lock.acquire()
            self.assertEqual(app.start(False), {"started": False, "busy": True})
            app.lock.release()

    def test_scheduled_job_also_marks_existing_mail_without_reclassification(self):
        with tempfile.TemporaryDirectory() as state:
            app = worker.Application(configuration(), Path(state))
            calls = []
            app.sorter = SimpleNamespace(
                run=lambda run_id, mark_read=False, labels=False: (
                    calls.append(
                        "read" if mark_read else "labels" if labels else "sort"
                    )
                    or {"planned": 0, "unclassified": 0, "dryRun": True}
                )
            )
            app.lock.acquire()
            with contextlib.redirect_stdout(io.StringIO()):
                app.finish({"id": "scheduled", "status": "running"}, False)
            # Nothing new was sorted, so old mail also gets its labels.
            self.assertEqual(calls, ["sort", "read", "labels"])
            self.assertEqual(app.previous["status"], "done")
            self.assertIn("existingRead", app.previous)
            self.assertIn("existingLabels", app.previous)
            self.assertFalse(app.lock.locked())


if __name__ == "__main__":
    unittest.main()
