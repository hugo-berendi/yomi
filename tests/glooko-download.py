"""Exercise the real Glooko CSV download flow in isolated Chromium."""

import importlib.util
import os
from pathlib import Path
import sys
import tempfile
from unittest.mock import patch

from playwright.sync_api import Browser, BrowserType


ROOT = Path(__file__).resolve().parents[1]
DEFAULT_SOURCE = ROOT / "hosts/nixos/inari/services/diabetes"
SOURCE = Path(sys.argv[2]) if len(sys.argv) > 2 else DEFAULT_SOURCE
MODULE = SOURCE / "glooko_sync.py"
sys.path.insert(0, str(SOURCE))
spec = importlib.util.spec_from_file_location("glooko_sync", MODULE)
glooko = importlib.util.module_from_spec(spec)
sys.modules[spec.name] = glooko
spec.loader.exec_module(glooko)

CSV = b"Type,Timestamp,Glucose (mg/dL)\ncgm,2020-01-02T03:04:05Z,123\n"
HTML = """<!doctype html><html><body>
<a id="open">Export to CSV</a><div id="dialog" role="dialog" hidden>
<h1>Als CSV exportieren</h1>
<div id="range"> <span>2</span><span>Wochen</span></div>
<div id="menu" hidden><div id="thirty"><span>30</span><span>Tage</span></div></div>
<button id="export">Exportieren</button></div>
<script>
let selectedDays = 14;
const dialog = document.querySelector('#dialog'), range = document.querySelector('#range');
document.querySelector('#open').onclick = () => dialog.hidden = false;
range.onclick = () => document.querySelector('#menu').hidden = false;
document.querySelector('#thirty').onclick = () => {
  selectedDays = 30; range.innerHTML = '<span>30</span><span>Tage</span>';
  document.querySelector('#menu').hidden = true;
};
document.querySelector('#export').onclick = () => {
  if (selectedDays !== 30) return;
  const url = URL.createObjectURL(new Blob([%s], {type: 'text/csv'}));
  const link = document.createElement('a'); link.href = url; link.download = 'export.csv';
  link.click();
};
</script></body></html>""" % repr(CSV.decode())

LOGIN_HTML = HTML.replace(
    '<a id="open">',
    '<form id="login"><input name="user[email]"><input name="user[password]" type="password">'
    '<button id="sign-in-button" type="button">Sign in</button></form><a id="open" hidden>',
).replace(
    "</body>",
    '<script>document.querySelector("#sign-in-button").onclick=()=>{'
    'document.querySelector("#login").remove();document.querySelector("#open").hidden=false;};'
    "</script></body>",
)
CHALLENGE_HTML = LOGIN_HTML.replace(
    'document.querySelector("#open").hidden=false;',
    'for(let i=0;i<6;i++){let e=document.createElement("input");e.maxLength=1;document.body.append(e);}',
)


def main():
    if len(sys.argv) < 2:
        raise SystemExit("usage: glooko-download.py CHROMIUM [SOURCE_DIRECTORY]")
    os.environ["GLOOKO_CHROMIUM"] = sys.argv[1]
    with tempfile.TemporaryDirectory(prefix="glooko-download-") as temp:
        root = Path(temp)
        credentials = {"email": "fixture@example.invalid", "password": "synthetic"}
        original_launch = BrowserType.launch
        original_context = Browser.new_context
        scenario = {"mode": "authenticated", "contexts": 0}

        def launch(browser_type, **kwargs):
            kwargs["chromium_sandbox"] = False
            return original_launch(browser_type, **kwargs)

        def context(browser, **kwargs):
            scenario["contexts"] += 1
            created = original_context(browser, **kwargs)
            created.route(
                "**/*",
                lambda route: (
                    route.fulfill(
                        status=200,
                        content_type="text/html; charset=utf-8",
                        body={
                            "authenticated": HTML,
                            "login": LOGIN_HTML,
                            "challenge": CHALLENGE_HTML,
                        }[scenario["mode"]],
                    )
                    if route.request.url.startswith("https://my.glooko.com/")
                    else route.abort()
                ),
            )
            return created

        with (
            patch.object(BrowserType, "launch", launch),
            patch.object(Browser, "new_context", context),
            # sudo can retain the operator's private XDG paths. The browser
            # must use its own state directory even when those are inaccessible.
            patch.dict(
                os.environ,
                {
                    "XDG_CONFIG_HOME": "/proc/1/yomi-inaccessible-config",
                    "XDG_CACHE_HOME": "/proc/1/yomi-inaccessible-cache",
                    "XDG_DATA_HOME": "/proc/1/yomi-inaccessible-data",
                    "XDG_STATE_HOME": "/proc/1/yomi-inaccessible-state",
                },
            ),
        ):
            payload = glooko.download_export(credentials, root=root, allow_login=False)
            # Exercise the unattended sync entry point, not just a browser helper.
            # A normal expired session may log in once; a challenge must pause.
            from app import init_db, database, get_state

            scheduled = root / "scheduled"
            init_db(scheduled)
            glooko.save_credentials(
                scheduled, credentials["email"], credentials["password"], "UTC"
            )
            scenario["mode"] = "login"
            assert glooko.sync(scheduled, now=2000000000) == "synced", (
                "unattended ordinary login did not import"
            )
            with database(scheduled) as db:
                assert db.execute("SELECT count(*) FROM records").fetchone()[0] == 1
            scenario["mode"] = "challenge"
            assert glooko.sync(scheduled, now=2000086400) == "authentication required"
            contexts = scenario["contexts"]
            assert glooko.sync(scheduled, now=2000172801) == "authentication required"
            assert scenario["contexts"] == contexts, (
                "challenge was automatically retried"
            )
            with database(scheduled) as db:
                assert (
                    get_state(db, "glooko")["error_code"] == "authentication_required"
                )
        assert payload == CSV
        records, notices = glooko.parse_export(payload, "UTC")
        assert records == [("cgm", 1577934245, 123.0, None)]
        assert notices == [], "synthetic export should not produce parser notices"
        session = root / "glooko-session.json"
        assert session.is_file(), "authenticated session state was not saved"
        assert session.stat().st_mode & 0o777 == 0o600, "session mode is not 0600"
    print(
        "PASS: real download, private session, inaccessible inherited XDG paths, unattended login and challenge pause"
    )


if __name__ == "__main__":
    main()
