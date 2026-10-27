"""Unattended CSV export using the personal Glooko website, not a public API."""

import contextlib
import fcntl
import hashlib
import json
import os
from pathlib import Path
import re
import tempfile
import time
from urllib.parse import urlsplit

from analysis import MAX_BYTES, parse_export
from quarantine import partition_records


class AuthenticationRequired(Exception):
    """Login rejected or interactive verification required; never retain page text."""


SYNC_STAGES = {
    "configuration": "reading the saved configuration",
    "session": "loading the saved session",
    "browser_start": "starting the browser",
    "browser_context": "opening the browser session",
    "navigation": "opening Glooko",
    "authentication": "signing in",
    "export_dialog": "opening the export dialog",
    "export_range_control": "loading the export range control",
    "export_range_option": "selecting the export period",
    "export_range_verify": "confirming the export period",
    "download": "downloading the export",
    "parse": "validating the export",
    "quarantine": "checking source timestamps",
    "import": "importing the records",
    "report": "calculating the report",
}
FAILURE_KINDS = {
    "authentication_required",
    "timeout",
    "browser_closed",
    "invalid_configuration",
    "invalid_export",
    "conflicting_records",
    "storage_error",
    "operation_failed",
    "future_timestamps",
    "range_control_absent",
    "range_control_ambiguous",
    "range_click_timeout",
    "range_option_missing",
    "range_option_ambiguous",
    "range_not_confirmed",
}


class ExportRangeError(ValueError):
    def __init__(self, kind):
        self.kind = kind
        super().__init__("Glooko export period could not be confirmed")


def failure_kind(error, stage):
    if isinstance(error, ExportRangeError):
        return error.kind if error.kind in FAILURE_KINDS else "operation_failed"
    if isinstance(error, AuthenticationRequired):
        return "authentication_required"
    if type(error).__name__ == "TimeoutError":
        return "timeout"
    if type(error).__name__ == "TargetClosedError":
        return "browser_closed"
    if isinstance(error, ValueError):
        if str(error).startswith(
            ("Export contains future records", "No timestamp-verified CGM records")
        ):
            return "future_timestamps"
        if stage == "configuration":
            return "invalid_configuration"
        if stage == "parse":
            return "invalid_export"
        if stage == "import" and str(error).startswith("Conflicting records"):
            return "conflicting_records"
    return "storage_error" if isinstance(error, OSError) else "operation_failed"


def retain_export(root, payload, name):
    directory = root / name
    directory.mkdir(mode=0o700, exist_ok=True)
    directory.chmod(0o700)
    target = directory / (hashlib.sha256(payload).hexdigest() + ".bin")
    if not target.exists():
        with tempfile.TemporaryDirectory(dir=directory) as pending:
            path = Path(pending) / "export.bin"
            with path.open("wb") as saved:
                os.chmod(path, 0o600)
                saved.write(payload)
                saved.flush()
                os.fsync(saved.fileno())
            os.replace(path, target)


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
    (root / "glooko-session.json").unlink(missing_ok=True)


EXPORT_LABEL = re.compile(r"^\s*(Als CSV exportieren|Export to CSV)\s*$", re.I)
CODE_LABEL = re.compile(
    r"^(Verification code|Authentication code|Security code|Code|Bestätigungscode|Authentifizierungscode|Sicherheitscode|Verifizierungscode|Einmalcode)$",
    re.I,
)
CODE_SELECTOR = 'input[autocomplete="one-time-code"], input[name*="otp" i], input[id*="otp" i], input[name*="verification_code" i], input[name*="authentication_code" i], input[name*="auth_code" i], input[name="code"], input[id="code"]'


def glooko_host(host):
    return host == "my.glooko.com" or (host or "").endswith(".my.glooko.com")


def trusted_page(page):
    url = urlsplit(page.url)
    if url.scheme != "https" or not glooko_host(url.hostname):
        raise AuthenticationRequired()


def save_browser_state(root, state):
    # Cookies are credentials. Retain only Glooko origins, never third parties.
    state = {
        "cookies": [
            cookie
            for cookie in state["cookies"]
            if cookie.get("domain", "").lstrip(".") == "glooko.com"
            or glooko_host(cookie.get("domain", "").lstrip("."))
        ],
        "origins": [
            origin
            for origin in state["origins"]
            if urlsplit(origin.get("origin", "")).scheme == "https"
            and glooko_host(urlsplit(origin.get("origin", "")).hostname)
        ],
    }
    temporary = root / "glooko-session.tmp"
    with temporary.open("w") as file:
        os.chmod(temporary, 0o600)
        json.dump(state, file)
        file.flush()
        os.fsync(file.fileno())
    os.replace(temporary, root / "glooko-session.json")


def load_browser_state(root):
    path = root / "glooko-session.json"
    if not path.exists():
        return None
    try:
        if path.stat().st_size > 1024 * 1024:
            raise ValueError()
        state = json.loads(path.read_text())
        if not isinstance(state, dict) or not all(
            isinstance(state.get(key), list) for key in ("cookies", "origins")
        ):
            raise ValueError()
        return state
    except (ValueError, OSError):
        raise AuthenticationRequired() from None


def authenticate_page(page, credentials, allow_login=False, code_prompt=None):
    """One login and at most one locally supplied code; never retry verification."""
    trusted_page(page)
    export = page.get_by_text(EXPORT_LABEL).filter(visible=True)
    password = page.locator('input[name="user[password]"]').filter(visible=True)
    named_codes = (
        page.locator(CODE_SELECTOR)
        .or_(page.get_by_label(CODE_LABEL))
        .filter(visible=True)
    )
    # The live email challenge has six text inputs with maxlength=1 but no
    # code-related name, id or autocomplete hint. Require the complete six-cell
    # layout before asking for a code; a lone one-character field is insufficient.
    single_digits = page.locator(
        'input[maxlength="1"]:is([type="text"], [type="tel"], [type="number"], :not([type]))'
    ).filter(visible=True)
    codes = named_codes.or_(single_digits).filter(visible=True)
    ready = export.or_(password).or_(codes).filter(visible=True).first
    ready.wait_for(state="visible", timeout=30000)
    if export.count():
        return export.first
    if not allow_login:
        raise AuthenticationRequired()
    if password.count():
        # OneTrust can appear after the initial document load. Wait briefly for
        # it before submitting, rather than checking once during that race.
        reject = page.locator("#onetrust-reject-all-handler")
        try:
            reject.wait_for(state="visible", timeout=3000)
        except Exception:
            pass
        if reject.is_visible():
            reject.click()
        trusted_page(page)
        page.locator('input[name="user[email]"]').fill(credentials["email"])
        password.fill(credentials["password"])
        page.locator("#sign-in-button").click()
        try:
            export.or_(codes).filter(visible=True).first.wait_for(
                state="visible", timeout=30000
            )
        except Exception:
            if password.count():
                raise AuthenticationRequired() from None
            raise
    trusted_page(page)
    if export.count():
        return export.first
    count = codes.count()
    if code_prompt is None or not count:
        raise AuthenticationRequired()
    if count == 1:
        if not named_codes.count():
            raise AuthenticationRequired()
    elif count != 6 or not all(
        codes.nth(i).get_attribute("maxlength") == "1" for i in range(count)
    ):
        raise AuthenticationRequired()
    code = code_prompt()
    if not isinstance(code, str) or not re.fullmatch(r"[A-Za-z0-9-]{4,12}", code):
        raise AuthenticationRequired()
    trusted_page(page)
    count = codes.count()
    if count == 1:
        codes.first.fill(code)
    elif count == len(code) and all(
        codes.nth(i).get_attribute("maxlength") == "1" for i in range(count)
    ):
        for i, character in enumerate(code):
            codes.nth(i).fill(character)
    else:
        raise AuthenticationRequired()
    # Some six-cell controls submit when the last digit is entered. If the
    # fields disappear, wait for the result instead of clicking a second submit.
    if not export.count():
        # Patient2FA/Choose2FA render divs, not forms. Their stable test IDs
        # identify the actual submit action across locales. click() waits for
        # React to enable Continue after its six-character state update.
        provider_submit = (
            page.get_by_test_id("patient-2fa-continue")
            .or_(page.get_by_test_id("choose-2fa-continue"))
            .filter(visible=True)
        )
        if provider_submit.count() == 1:
            provider_submit.click()
        else:
            form = codes.first.locator("xpath=ancestor::form[1]")
            submit = form.locator('button[type="submit"], input[type="submit"]').filter(
                visible=True
            )
            if submit.count() == 1 and submit.is_enabled():
                submit.click()
            else:
                button = page.get_by_role(
                    "button",
                    name=re.compile(
                        r"^(Verify( code)?|Confirm|Continue|Submit|Authenticate|Bestätigen|Überprüfen|Verifizieren|Fortfahren|Anmelden)$",
                        re.I,
                    ),
                ).filter(visible=True)
                if button.count() == 1 and button.is_enabled():
                    button.click()
    try:
        export.first.wait_for(state="visible", timeout=30000)
    except Exception:
        raise AuthenticationRequired() from None
    trusted_page(page)
    return export.first


THIRTY_DAYS = re.compile(r"^\s*30\s*(Tage|days)\s*$", re.I)
EXPORT_PERIOD = re.compile(
    r"^\s*(?:1\s*(?:Tag|day|Woche|week)|2\s*(?:Wochen|weeks)|30\s*(?:Tage|days)|90\s*(?:Tage|days)|Benutzerdefinierter\s*Zeitraum|Custom\s*Range)\s*$",
    re.I,
)


def select_export_range(page, dialog, progress=None):
    """Choose and verify 30 days without assuming a previous range or ASCII spaces."""
    from playwright.sync_api import expect, TimeoutError as BrowserTimeout

    mark = progress or (lambda stage: None)
    dialog.wait_for(state="visible")
    mark("export_range_control")
    native = dialog.locator("select").filter(visible=True)
    button = dialog.get_by_role("button", name=EXPORT_PERIOD).filter(visible=True)
    text = dialog.get_by_text(EXPORT_PERIOD).filter(visible=True)
    # Dialog shells can mount before react-select's visible value. count() does
    # not wait; choosing the already-mounted dummy INPUT makes click retry on
    # an offscreen element forever. Wait for an actual visible range control.
    try:
        native.or_(button).or_(text).first.wait_for(state="visible")
    except BrowserTimeout:
        raise ExportRangeError("range_control_absent") from None
    if native.count() == 1:
        mark("export_range_option")
        choices = [
            option
            for option in native.locator("option").all()
            if THIRTY_DAYS.fullmatch(option.inner_text())
        ]
        if len(choices) != 1:
            raise ExportRangeError(
                "range_option_missing" if not choices else "range_option_ambiguous"
            )
        native.select_option(label=choices[0].inner_text())
        if not THIRTY_DAYS.fullmatch(native.locator("option:checked").inner_text()):
            raise ExportRangeError("range_not_confirmed")
        return
    # react-select exposes an opacity-zero dummy INPUT as a combobox. The live
    # export dialog's visible value DIV is the clickable target and also holds
    # the selected range; the dummy input has neither a click point nor a value.
    control = button
    if not control.count():
        control = text
    if control.count() != 1:
        raise ExportRangeError("range_control_ambiguous")
    is_input = control.evaluate("element => element.tagName === 'INPUT'")
    current = control.input_value() if is_input else control.inner_text()
    if THIRTY_DAYS.fullmatch(current):
        return
    try:
        control.click()
    except BrowserTimeout:
        raise ExportRangeError("range_click_timeout") from None
    mark("export_range_option")
    try:
        page.get_by_role("option", name=THIRTY_DAYS).or_(
            page.get_by_text(THIRTY_DAYS)
        ).filter(visible=True).first.wait_for(state="visible")
    except BrowserTimeout:
        raise ExportRangeError("range_option_missing") from None
    option = page.get_by_role("option", name=THIRTY_DAYS).filter(visible=True)
    if not option.count():
        option = page.get_by_text(THIRTY_DAYS).filter(visible=True)
    if option.count() != 1:
        raise ExportRangeError(
            "range_option_missing" if not option.count() else "range_option_ambiguous"
        )
    option.click()
    mark("export_range_verify")
    try:
        if is_input:
            expect(control).to_have_value(THIRTY_DAYS)
        else:
            expect(control).to_have_text(THIRTY_DAYS)
    except AssertionError:
        raise ExportRangeError("range_not_confirmed") from None


def download_export(
    credentials, root=None, allow_login=False, code_prompt=None, progress=None
):
    # Browser objects never escape this call; only private session state persists.
    from playwright.sync_api import sync_playwright

    mark = progress or (lambda stage: None)
    mark("session")
    state = None
    browser_environment = None
    if root is not None:
        root = Path(root).resolve()
        # sudo may retain the operator's XDG paths, which the service user
        # cannot access. Chromium's crash handler then exits before any login.
        browser_environment = os.environ | {
            "HOME": str(root),
            "XDG_CONFIG_HOME": str(root / "browser-config"),
            "XDG_CACHE_HOME": str(root / "browser-cache"),
            "XDG_DATA_HOME": str(root / "browser-data"),
            "XDG_STATE_HOME": str(root / "browser-state"),
        }
        try:
            state = load_browser_state(root)
        except AuthenticationRequired:
            if not allow_login:
                raise
    mark("browser_start")
    with sync_playwright() as driver:
        browser = driver.chromium.launch(
            executable_path=os.environ.get("GLOOKO_CHROMIUM"),
            headless=True,
            chromium_sandbox=True,
            env=browser_environment,
        )
        try:
            mark("browser_context")
            context = browser.new_context(
                accept_downloads=True, locale="de-DE", storage_state=state
            )
            page = context.new_page()
            page.set_default_timeout(30000)
            mark("navigation")
            page.goto("https://my.glooko.com/users/sign_in?locale=de")
            mark("authentication")
            export = authenticate_page(
                page, credentials, allow_login=allow_login, code_prompt=code_prompt
            )
            if root is not None:
                save_browser_state(root, context.storage_state())
            mark("export_dialog")
            export.click()
            dialog = page.get_by_role("dialog").filter(
                has_text=re.compile(r"Als CSV exportieren|Export to CSV", re.I)
            )
            # Confirm the actual selected range before requesting any download.
            select_export_range(page, dialog, progress=mark)
            mark("download")
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


def sync(
    root, fetch=None, now=None, refresh=False, interactive=False, code_prompt=None
):
    # Imported here to avoid a module cycle when invoked from the web process.
    from app import (
        database,
        import_records,
        build_report,
        get_state,
        put_state,
        VERIFIED_RECORDS,
    )

    now = int(time.time() if now is None else now)
    stage = "configuration"

    def progress(value):
        nonlocal stage
        if value in SYNC_STAGES:
            stage = value

    try:
        with sync_lock(root):
            path = root / "glooko-credentials.json"
            if not path.exists():
                return "not configured"
            with database(root) as db:
                state = get_state(db, "glooko", {})
                if (
                    not interactive
                    and now < state.get("next_attempt", 0)
                    and not (
                        refresh
                        and state.get("success")
                        and state.get("success") == state.get("attempt")
                        and not state.get("error")
                    )
                ):
                    return "not due"
                if (
                    not interactive
                    and state.get("error_code") == "authentication_required"
                ):
                    return "authentication required"
                # Persist a backoff before network work, including crashes/timeouts.
                state.update(attempt=now, next_attempt=now + 6 * 3600, error=None)
                put_state(db, "glooko", state)
            try:
                credentials = json.loads(path.read_text())
                progress("download")
                payload = (
                    fetch(credentials)
                    if fetch is not None
                    else download_export(
                        credentials,
                        root=root,
                        # Ordinary session expiry may use the saved login once.
                        # MFA still requires code_prompt; a challenge pauses later
                        # attempts above until the human completes local login.
                        allow_login=True,
                        code_prompt=code_prompt,
                        progress=progress,
                    )
                )
                progress("parse")
                records, notices = parse_export(
                    payload, credentials["timezone"], "day-first"
                )
                if not any(row[0] == "cgm" for row in records):
                    raise ValueError("No CGM records")
                progress("quarantine")
                # Preserve uncertain groups before validating the remainder. A
                # later import conflict must not lose their immutable evidence.
                with database(root) as db:
                    records, held_notices = partition_records(
                        db, records, int(time.time())
                    )
                notices += held_notices
                state["notices"] = notices
                # Commit the ledger before archiving. An archive failure must
                # not let a later retry silently admit the same source times.
                if any("local clock-change timestamps" in n for n in notices):
                    retain_export(root, payload, "glooko-clock-change-exports")
                if held_notices:
                    retain_export(root, payload, "glooko-quarantine-exports")
                if not any(row[0] == "cgm" for row in records):
                    raise ValueError("No timestamp-verified CGM records")
                progress("import")
                with database(root) as db:
                    db.execute("BEGIN IMMEDIATE")
                    inserted = import_records(db, records)
                    progress("report")
                    build_report(db)
                    state.update(
                        success=now,
                        next_attempt=now + 86400,
                        added=inserted,
                        latest_cgm=db.execute(
                            f"SELECT max(ts) FROM records WHERE kind='cgm' AND {VERIFIED_RECORDS}"
                        ).fetchone()[0],
                        notices=notices,
                        error=None,
                        error_code=None,
                        failure_stage=None,
                        failure_kind=None,
                    )
                    put_state(db, "glooko", state)
                return "synced"
            except Exception as error:
                # Browser exceptions can include form values, page text and URLs.
                # Retain only this fixed message; no exception or traceback logging.
                with database(root) as db:
                    state["error"] = (
                        f"Glooko sync did not finish while {SYNC_STAGES[stage]}. "
                        "Existing data was kept."
                    )
                    state["failure_stage"] = stage
                    state["failure_kind"] = failure_kind(error, stage)
                    if isinstance(error, AuthenticationRequired):
                        state["error_code"] = "authentication_required"
                        state["error"] = (
                            "Glooko needs a local login or verification code. On Inari, run sudo -u diabetes /run/current-system/sw/bin/diabetes-glooko-login in a terminal. Automatic login attempts are paused until you complete this. Existing history was kept."
                        )
                        state["next_attempt"] = now + 86400
                    else:
                        state["error_code"] = "sync_failed"
                    put_state(db, "glooko", state)
                return (
                    "authentication required"
                    if isinstance(error, AuthenticationRequired)
                    else "failed"
                )
    except ValueError:
        return "already running"
