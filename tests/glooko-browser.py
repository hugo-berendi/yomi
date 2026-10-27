"""Real Chromium integration coverage for Glooko's guarded login flow.

All network requests are intercepted: this test never contacts Glooko or another
external service and uses only synthetic fixture credentials and OTP values.
"""

import importlib.util
from pathlib import Path
import sys
from unittest.mock import patch

from playwright.sync_api import Locator, sync_playwright


ROOT = Path(__file__).resolve().parents[1]
MODULE_PATH = ROOT / "hosts/nixos/inari/services/diabetes/glooko_sync.py"
sys.path.insert(0, str(MODULE_PATH.parent))
spec = importlib.util.spec_from_file_location("glooko_sync", MODULE_PATH)
glooko = importlib.util.module_from_spec(spec)
sys.modules[spec.name] = glooko
spec.loader.exec_module(glooko)

SIGN_IN = "https://my.glooko.com/users/sign_in?locale=de"
EMAIL = "fixture@example.invalid"
PASSWORD = "synthetic-fixture-password"
OTP = "123456"


def fixture_html(state="password", multi_otp=False):
    if state == "export":
        return "<main><button>Export to CSV</button></main>"
    if state == "password":
        return """<form id="login">
          <input name="user[email]"><input name="user[password]" type="password">
          <button id="sign-in-button">Sign in</button></form>
          <script>document.querySelector('#login').onsubmit=e=>{
            e.preventDefault(); document.body.innerHTML =
              '<form id="otp"><input autocomplete="one-time-code" name="user[otp_attempt]">'
              + '<button>Verify</button></form>';
            document.querySelector('#otp').onsubmit=x=>{x.preventDefault();
              document.body.innerHTML='<main><button>Export to CSV</button></main>'};
          }</script>"""
    if state == "rejected-password":
        return """<form id="login">
          <input name="user[email]"><input name="user[password]" type="password">
          <button id="sign-in-button">Sign in</button></form>"""
    if state == "patient-otp":
        # Glooko Patient2FA public frontend: div, six unnamed cells, a disabled
        # type=button with a stable testid, and a locale-dependent label.
        fields = '<input type="text" maxlength="1">' * 6
        return f"""<div id="patient-2fa-form">{fields}<input type="checkbox">
          <button type="button" data-testid="patient-2fa-continue" disabled>Weiter</button></div>
          <script>
          const button=document.querySelector('button');
          document.querySelectorAll('input[maxlength]').forEach(i=>i.oninput=()=>{{
            setTimeout(()=>{{button.disabled=Array.from(document.querySelectorAll('input[maxlength]')).map(i=>i.value).join('').length!==6}},50)
          }});
          button.onclick=()=>{{if(Array.from(document.querySelectorAll('input[maxlength]')).map(i=>i.value).join('')==='123456') document.body.innerHTML='<button>Export to CSV</button>'}};
          </script>"""
    if state in {"anonymous-otp", "anonymous-auto-otp"}:
        fields = '<input type="text" maxlength="1">' * 6
        auto = (
            "document.querySelectorAll('input[maxlength]').forEach(i=>i.oninput=verify);"
            if state == "anonymous-auto-otp"
            else ""
        )
        return f"""<form id="verification">{fields}<input type="checkbox"><button type="submit">Verify</button></form>
          <script>
          function verify() {{
            const code = Array.from(document.querySelectorAll('input[maxlength]')).map(i=>i.value).join('');
            if (code === '123456') document.body.innerHTML='<main><button>Export to CSV</button></main>';
          }}
          document.querySelector('form').onsubmit=e=>{{e.preventDefault();verify()}};
          {auto}
          </script>"""
    if multi_otp:
        fields = "".join(f'<input name="otp{i}" maxlength="1">' for i in range(6))
    else:
        fields = '<input autocomplete="one-time-code" name="user[otp_attempt]">'
    return f"""<form id="otp">{fields}<button>Verify</button></form>
      <script>document.querySelector('#otp').onsubmit=e=>{{e.preventDefault();
      document.body.innerHTML='<main><button>Export to CSV</button></main>'}}</script>"""


def run_case(
    chromium,
    state,
    *,
    allow_login=False,
    code_prompt=None,
    multi_otp=False,
    expect_export=False,
    expect_auth=False,
    prompt_called=None,
):
    browser = chromium.launch(
        executable_path=sys.argv[1], headless=True, chromium_sandbox=False
    )
    try:
        context = browser.new_context()
        # Deny every request except the one HTTPS origin served by this fixture.
        context.route(
            "**/*",
            lambda route: (
                route.fulfill(
                    status=200,
                    content_type="text/html; charset=utf-8",
                    body=fixture_html(state, multi_otp),
                )
                if route.request.url.startswith("https://my.glooko.com/")
                else route.abort()
            ),
        )
        page = context.new_page()
        page.goto(SIGN_IN)
        try:

            def authenticate():
                return glooko.authenticate_page(
                    page,
                    {"email": EMAIL, "password": PASSWORD},
                    allow_login=allow_login,
                    code_prompt=code_prompt,
                )

            if state == "rejected-password":
                original_wait_for = Locator.wait_for

                def short_wait(locator, **kwargs):
                    # The rejection stays fast without racing the first browser
                    # IPC round-trip when Nix checks run concurrently.
                    kwargs["timeout"] = min(kwargs.get("timeout", 1000), 1000)
                    return original_wait_for(locator, **kwargs)

                with patch.object(Locator, "wait_for", short_wait):
                    export = authenticate()
            else:
                export = authenticate()
        except glooko.AuthenticationRequired:
            assert expect_auth
            assert page.locator("#sign-in-button").count() == (
                1 if state in {"password", "rejected-password"} else 0
            )
            if prompt_called is not None:
                assert not prompt_called
            return
        assert expect_export, "authentication unexpectedly returned an export control"
        assert export.is_visible()
    finally:
        browser.close()


def run_export_case(chromium, kind):
    browser = chromium.launch(
        executable_path=sys.argv[1], headless=True, chromium_sandbox=False
    )
    try:
        context = browser.new_context()
        if kind in {"native", "native-missing"}:
            control = '<select aria-label="Zeitraum"><option value="14">2\u00a0Wochen</option><option value="30">30\u00a0Tage</option></select>'
            if kind == "native-missing":
                control = '<select aria-label="Zeitraum"><option value="14">2 Wochen</option></select>'
            script = "window.selectedDays=14; document.querySelector('select').onchange=e=>window.selectedDays=Number(e.target.value)"
        else:
            initial = {
                "nbsp": "2\u00a0Wochen",
                "split": "2<span>Wochen</span>",
                "ninety": "90 days",
                "already": "30 Tage",
                "delayed": "2 Wochen",
                "dummy-combobox": "2 Wochen",
                "delayed-control": "2 Wochen",
            }[kind]
            role = (
                'role="combobox"'
                if kind not in {"split", "dummy-combobox", "delayed-control"}
                else ""
            )
            control = f'<div id="range" {role}>{initial}</div><div id="options" role="listbox" hidden><div role="option" id="thirty">30<span>Tage</span></div></div>'
            script = f"""window.selectedDays={30 if kind == "already" else 90 if kind == "ninety" else 14}; window.openCount=0;
            document.querySelector('#range').onclick=()=>{{window.openCount++;document.querySelector('#options').hidden=false}};
            document.querySelector('#thirty').onclick=()=>{{window.selectedDays=30;document.querySelector('#range').textContent='30 Tage';document.querySelector('#options').hidden=true}};
            """
        if kind in {"dummy-combobox", "delayed-control"}:
            control += '<input role="combobox" aria-readonly="true" style="opacity:0;width:1px;height:18px;position:absolute;left:-100px;transform:scale(.01)">'
        if kind == "delayed-control":
            script = (
                "document.querySelector('#range').hidden=true;"
                + script
                + "setTimeout(()=>document.querySelector('#range').hidden=false,300);"
            )
        if kind == "delayed":
            script = script.replace(
                "document.querySelector('#options').hidden=false",
                "setTimeout(()=>{document.querySelector('#options').hidden=false},100)",
            )
        html = f'<div role="dialog"><h2>Als CSV exportieren</h2>{control}<button>Exportieren</button></div><script>{script}</script>'
        context.route(
            "**/*",
            lambda route: route.fulfill(
                status=200, content_type="text/html; charset=utf-8", body=html
            ),
        )
        page = context.new_page()
        page.goto(SIGN_IN)
        if kind == "delayed-control":
            page.set_default_timeout(1500)
        try:
            glooko.select_export_range(page, page.get_by_role("dialog"))
        except ValueError:
            assert kind == "native-missing", "valid range control must work"
            assert page.evaluate("window.selectedDays") == 14
            return
        assert kind != "native-missing", "missing 30-day choice must stop the export"
        assert page.evaluate("window.selectedDays") == 30, (
            "must select actual 30-day range"
        )
        if kind == "already":
            assert page.evaluate("window.openCount") == 0, (
                "already-selected 30 days must be accepted without toggling"
            )
    finally:
        browser.close()


def main():
    assert len(sys.argv) == 2, "usage: glooko-browser.py /path/to/chromium"
    with sync_playwright() as driver:
        chromium = driver.chromium
        for kind in (
            "nbsp",
            "split",
            "ninety",
            "native",
            "already",
            "native-missing",
            "delayed",
            "dummy-combobox",
            "delayed-control",
        ):
            run_export_case(chromium, kind)
        # Existing signed-in session: no password or callback should be needed.
        run_case(chromium, "export", expect_export=True)
        # Interactive login and OTP, both as one field and six one-character fields.
        run_case(
            chromium,
            "password",
            allow_login=True,
            code_prompt=lambda: OTP,
            expect_export=True,
        )
        run_case(
            chromium,
            "otp",
            allow_login=True,
            code_prompt=lambda: OTP,
            multi_otp=True,
            expect_export=True,
        )
        # Observed Glooko MFA layout: six inputs with no code name, id or
        # autocomplete hint, plus an unrelated checkbox. Check both submit modes.
        run_case(
            chromium,
            "anonymous-otp",
            allow_login=True,
            code_prompt=lambda: OTP,
            expect_export=True,
        )
        run_case(
            chromium,
            "anonymous-auto-otp",
            allow_login=True,
            code_prompt=lambda: OTP,
            expect_export=True,
        )
        run_case(chromium, "anonymous-otp", expect_auth=True)
        run_case(
            chromium,
            "patient-otp",
            allow_login=True,
            code_prompt=lambda: OTP,
            expect_export=True,
        )
        # Unattended paths stop before submitting either password or OTP.
        run_case(chromium, "password", expect_auth=True)
        run_case(chromium, "otp", expect_auth=True)
        # A rejected password remains visible; classify it as auth failure without
        # requesting an OTP. The callback is guarded by a mutable test sentinel.
        callback_calls = []
        run_case(
            chromium,
            "rejected-password",
            allow_login=True,
            code_prompt=lambda: callback_calls.append(OTP),
            expect_auth=True,
            prompt_called=callback_calls,
        )


if __name__ == "__main__":
    main()
