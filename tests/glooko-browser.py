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
                    kwargs["timeout"] = min(kwargs.get("timeout", 100), 100)
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


def main():
    assert len(sys.argv) == 2, "usage: glooko-browser.py /path/to/chromium"
    with sync_playwright() as driver:
        chromium = driver.chromium
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
