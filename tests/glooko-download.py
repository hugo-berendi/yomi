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


def main():
    if len(sys.argv) < 2:
        raise SystemExit("usage: glooko-download.py CHROMIUM [SOURCE_DIRECTORY]")
    os.environ["GLOOKO_CHROMIUM"] = sys.argv[1]
    with tempfile.TemporaryDirectory(prefix="glooko-download-") as temp:
        root = Path(temp)
        credentials = {"email": "fixture@example.invalid", "password": "synthetic"}
        original_launch = BrowserType.launch
        original_context = Browser.new_context

        def launch(browser_type, **kwargs):
            kwargs["chromium_sandbox"] = False
            return original_launch(browser_type, **kwargs)

        def context(browser, **kwargs):
            created = original_context(browser, **kwargs)
            created.route(
                "**/*",
                lambda route: (
                    route.fulfill(
                        status=200,
                        content_type="text/html; charset=utf-8",
                        body=HTML,
                    )
                    if route.request.url.startswith("https://my.glooko.com/")
                    else route.abort()
                ),
            )
            return created

        with (
            patch.object(BrowserType, "launch", launch),
            patch.object(Browser, "new_context", context),
        ):
            payload = glooko.download_export(credentials, root=root, allow_login=False)
        assert payload == CSV
        records, notices = glooko.parse_export(payload, "UTC")
        assert records == [("cgm", 1577934245, 123.0, None)]
        assert notices == [], "synthetic export should not produce parser notices"
        session = root / "glooko-session.json"
        assert session.is_file(), "authenticated session state was not saved"
        assert session.stat().st_mode & 0o777 == 0o600, "session mode is not 0600"
    print("PASS: real download_export returned exact synthetic CSV; session mode 0600")


if __name__ == "__main__":
    main()
