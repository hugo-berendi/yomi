"""Unattended CSV export using the personal Glooko website, not a public API."""

import contextlib
import fcntl
import json
import os
from pathlib import Path
import re
import time
from urllib.parse import urlsplit

from analysis import MAX_BYTES, parse_export


@contextlib.contextmanager
def sync_lock(root):
    with (root / "glooko.lock").open("a") as lock:
        try:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            raise ValueError(
                "Glooko sync is running. Try again when it finishes."
            ) from None
        yield


def save_credentials(root, email, password, zone):
    if not email.strip() or not password or zone not in {"UTC", "Europe/Berlin"}:
        raise ValueError("Enter your Glooko email, password and export timezone")
    temporary = root / "glooko-credentials.tmp"
    with temporary.open("w") as file:
        os.chmod(temporary, 0o600)
        json.dump(
            {"email": email.strip(), "password": password, "timezone": zone}, file
        )
        file.flush()
        os.fsync(file.fileno())
    os.replace(temporary, root / "glooko-credentials.json")


def download_export(credentials):
    # Import lazily so the web process does not need a running browser.
    from playwright.sync_api import sync_playwright

    with sync_playwright() as driver:
        browser = driver.chromium.launch(
            executable_path=os.environ.get("GLOOKO_CHROMIUM"),
            headless=True,
            chromium_sandbox=True,
        )
        try:
            context = browser.new_context(accept_downloads=True, locale="de-DE")
            page = context.new_page()
            page.set_default_timeout(30000)
            page.goto("https://my.glooko.com/users/sign_in?locale=de")
            # Credentials must never follow a changed login destination.
            url = urlsplit(page.url)
            if url.scheme != "https" or not (
                url.hostname == "my.glooko.com"
                or (url.hostname or "").endswith(".my.glooko.com")
            ):
                raise ValueError("Unexpected Glooko login destination")
            reject = page.locator("#onetrust-reject-all-handler")
            if reject.is_visible():
                reject.click()
            page.locator('input[name="user[email]"]').fill(credentials["email"])
            page.locator('input[name="user[password]"]').fill(credentials["password"])
            # Do not record browser traces, screenshots, cookies or response bodies.
            page.locator("#sign-in-button").click()
            page.get_by_text(
                re.compile(r"^(Als CSV exportieren|Export to CSV)$", re.I)
            ).click()
            dialog = page.get_by_role("dialog").filter(
                has_text=re.compile(r"Als CSV exportieren|Export to CSV", re.I)
            )
            # The default two-week window may omit part of the comparison.
            # Select 30 days explicitly; fail instead of accepting a shorter range.
            dialog.get_by_text(re.compile(r"^(2 Wochen|2 weeks)$", re.I)).click()
            page.get_by_text(re.compile(r"^30 (Tage|days)$", re.I)).click()
            with page.expect_download(timeout=150000) as pending:
                dialog.get_by_role(
                    "button", name=re.compile(r"^(Export|Exportieren)$", re.I)
                ).click()
            download = pending.value
            try:
                path = Path(download.path())
                with path.open("rb") as file:
                    payload = file.read(MAX_BYTES + 1)
                if len(payload) > MAX_BYTES:
                    raise ValueError("Glooko export exceeds import limit")
                return payload
            finally:
                download.delete()
        finally:
            browser.close()


def sync(root, fetch=download_export, now=None):
    # Imported here to avoid a module cycle when invoked from the web process.
    from app import database, import_records, build_report, get_state, put_state

    now = int(time.time() if now is None else now)
    try:
        with sync_lock(root):
            path = root / "glooko-credentials.json"
            if not path.exists():
                return "not configured"
            with database(root) as db:
                state = get_state(db, "glooko", {})
                if now < state.get("next_attempt", 0):
                    return "not due"
                # Persist a backoff before network work, including crashes/timeouts.
                state.update(attempt=now, next_attempt=now + 6 * 3600, error=None)
                put_state(db, "glooko", state)
            try:
                credentials = json.loads(path.read_text())
                payload = fetch(credentials)
                records, notices = parse_export(
                    payload, credentials["timezone"], "day-first"
                )
                if not any(row[0] == "cgm" for row in records):
                    raise ValueError("No CGM records")
                with database(root) as db:
                    db.execute("BEGIN IMMEDIATE")
                    inserted = import_records(db, records)
                    build_report(db)
                    state.update(
                        success=now,
                        next_attempt=now + 86400,
                        added=inserted,
                        latest_cgm=max(row[1] for row in records if row[0] == "cgm"),
                        notices=notices,
                        error=None,
                    )
                    put_state(db, "glooko", state)
                return "synced"
            except Exception:
                # Browser exceptions can include form values, page text and URLs.
                # Retain only this fixed message; no exception or traceback logging.
                with database(root) as db:
                    state["error"] = (
                        "Glooko sync did not finish. Check your login, device sync and "
                        "export timezone. A login challenge, website change or conflicting "
                        "export can also require attention. Existing data was kept."
                    )
                    put_state(db, "glooko", state)
                return "failed"
    except ValueError:
        return "already running"
