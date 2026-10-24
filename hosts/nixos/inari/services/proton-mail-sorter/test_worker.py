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
from unittest.mock import patch

import classifier
import worker


CERT = b"synthetic-bridge-certificate"


def configuration(apply=False):
    return {
        "apply": apply, "maxMessages": 50, "maxReadMessages": 1000, "markExistingRead": True, "bridgeHost": "127.0.0.1", "bridgePort": 1143,
        "bridgeCertificateSha256": hashlib.sha256(CERT).hexdigest(),
        "ollamaUrl": "http://127.0.0.1:8442", "opExecutable": "/test/op",
        "usernameRef": "op://Automation/Bridge/username",
        "passwordRef": "op://Automation/Bridge/password",
        "apiTokenRef": "op://Automation/Sorter/api-token",
    }


class FakeSecrets:
    def get(self, field):
        return "x" * 40 if field == "apiTokenRef" else "synthetic"


class Mailbox:
    def __init__(self, missing=False, changed=False, invalid_uid=False, no_move=False, certificate=CERT, store_fail=False):
        self.current = None
        self.queries = []
        self.commands = []
        self.created = []
        self.logged_out = False
        self.status_calls = 0
        self.missing, self.changed, self.invalid_uid, self.store_fail = missing, changed, invalid_uid, store_fail
        self.names = ["INBOX", "Archive", "Sent", "Drafts", "Spam", "Trash", "All Mail", "Labels/Test", "Folders/Unknown", "Folders/Werbung/Sub"]
        self.names += ["Folders/" + prefix + category for prefix in ("", "KI-") for category in classifier.CATEGORIES]
        self.folder = SimpleNamespace(
            list=lambda: [SimpleNamespace(name=n, delim="/", flags=()) for n in self.names],
            set=self.select, status=self.status, create=self.created.append,
        )
        self.client = SimpleNamespace(
            socket=lambda: SimpleNamespace(getpeercert=lambda **kw: certificate),
            capability=lambda: ("OK", [b"IMAP4rev1" if no_move else b"IMAP4rev1 MOVE"]), uid=self.uid,
        )

    def select(self, name):
        self.current = name

    def status(self, *args):
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
        data = b"changed" if self.changed and query.startswith("UID ") else b"synthetic-message"
        return iter([SimpleNamespace(uid="1", subject="Synthetic mail", text="Synthetic body", html="", from_="sender@example.invalid", obj=SimpleNamespace(as_bytes=lambda: data))])

    def uid(self, *args):
        assert args[0] in ("STORE", "MOVE")
        if args[0] == "STORE":
            assert args[1:] == ("1", "+FLAGS.SILENT", "(\\Seen)")
        self.commands.append((self.current, args))
        return ("NO", []) if self.store_fail and args[0] == "STORE" else ("OK", [])


class WorkerTests(unittest.TestCase):
    def test_local_classifier_schema_and_twitch_boundary(self):
        msg = SimpleNamespace(text="Schau jetzt auf Twitch zu", html="", from_="no-reply@twitch.tv", subject="LexoLeni ist live: Einmal Ente suess sauer")
        with patch.object(classifier, "ZoneInfo", return_value=timezone.utc), patch.object(classifier.urllib.request, "build_opener", side_effect=AssertionError("Twitch must bypass the model")):
            self.assertEqual(classifier.classify(msg), "Werbung")
        msg.from_ = "no-reply@twitch.tv.attacker.invalid"
        requests = []
        def open_request(request, **kwargs):
            requests.append(json.loads(request.data))
            return io.BytesIO(json.dumps({"message": {"content": json.dumps({"folder": "Newsletter"})}}).encode())
        with patch.object(classifier, "ZoneInfo", return_value=timezone.utc), patch.object(classifier.urllib.request, "build_opener", return_value=SimpleNamespace(open=open_request)):
            self.assertEqual(classifier.classify(msg), "Newsletter")
        self.assertEqual(requests[0]["model"], "qwen3.5:9b")
        self.assertEqual(requests[0]["format"]["properties"]["folder"]["enum"], classifier.CATEGORIES)
        self.assertFalse(requests[0]["format"]["additionalProperties"])

    def test_config_and_schema(self):
        self.assertEqual(len(classifier.CATEGORIES), 13)
        self.assertEqual(classifier.MODEL, "qwen3.5:9b")
        worker.validate_config(configuration())
        for changes in ({"bridgeCertificateSha256": ""}, {"passwordRef": "plaintext"}, {"maxMessages": True}, {"bridgePort": 0}, {"ollamaUrl": "https://user:secret@host"}):
            with self.assertRaises(ValueError):
                worker.validate_config({**configuration(), **changes})

    def test_pin_from_pem_matches_the_der_the_connection_checks(self):
        import ssl
        der = b"0\x03\x02\x01\x00"  # any bytes: the pin is a hash of DER, not a parse
        with tempfile.TemporaryDirectory() as directory:
            pem = Path(directory, "bridge.pem")
            pem.write_text(ssl.DER_cert_to_PEM_cert(der), encoding="ascii")
            config = worker.validate_config({**configuration(), "bridgeCertificateSha256": "0" * 64, "bridgeCertificateFile": str(pem)})
        self.assertEqual(config["bridgeCertificateSha256"], hashlib.sha256(der).hexdigest())

    def run_sorter(self, box, state, apply=False, mark_read=False, verdict="Rechnungen", max_messages=50):
        config = {**configuration(apply), "maxMessages": max_messages}
        sorter = worker.Sorter(config, FakeSecrets(), Path(state), lambda *args, **kwargs: box)
        with patch.object(classifier, "classify", return_value=verdict) as classify:
            result = sorter.run("test-run", mark_read)
        return result, classify.call_count

    def test_dry_run_only_inbox_archive_and_cache(self):
        with tempfile.TemporaryDirectory() as state:
            box = Mailbox()
            result, calls = self.run_sorter(box, state)
            self.assertEqual(result["planned"], 2)
            self.assertEqual(calls, 2)
            self.assertEqual({q[0] for q in box.queries}, {"INBOX", "Archive"})
            self.assertFalse(box.commands or box.created)
            self.assertTrue(box.logged_out)
            sorter = worker.Sorter(configuration(), FakeSecrets(), Path(state), lambda *a, **kw: Mailbox())
            with patch.object(classifier, "classify", side_effect=AssertionError("Cached mail must not call the model")):
                sorter.run("second-run")

    def test_store_before_move(self):
        with tempfile.TemporaryDirectory() as state:
            box = Mailbox()
            result, _ = self.run_sorter(box, state, apply=True)
            self.assertEqual(result["moved"], 2)
            self.assertEqual(result["markedRead"], 2)
            self.assertEqual([c[1][0] for c in box.commands], ["STORE", "MOVE", "STORE", "MOVE"])
            rows = [json.loads(line) for line in (Path(state) / "actions-test-run.jsonl").read_text(encoding="utf-8").splitlines()]
            self.assertEqual([row["status"] for row in rows], ["pending", "done"] * 4)

    def test_wichtig_preserves_flags_and_budget(self):
        with tempfile.TemporaryDirectory() as state:
            box = Mailbox()
            result, calls = self.run_sorter(box, state, apply=True, verdict="Wichtig", max_messages=1)
            self.assertEqual(result["moved"], 1)
            self.assertEqual(calls, 1)
            self.assertEqual([c[1][0] for c in box.commands], ["MOVE"])

    def test_retroactive_reads_only_category_unseen_headers_without_ai(self):
        with tempfile.TemporaryDirectory() as state:
            box = Mailbox(no_move=True)
            result, calls = self.run_sorter(box, state, apply=True, mark_read=True)
            self.assertEqual(calls, 0)
            self.assertEqual(result["markedRead"], 2 * (len(classifier.CATEGORIES) - 1))
            self.assertEqual(result["moved"], 0)
            self.assertTrue(all(c[1][0] == "STORE" for c in box.commands))
            self.assertTrue(all(q[2]["headers_only"] for q in box.queries))
            self.assertTrue(all(q[1] == "UNSEEN" or q[1] == "UID 1" for q in box.queries))
            self.assertFalse(any(q[0] in ("INBOX", "Archive", "Folders/Wichtig", "Folders/KI-Wichtig", "Folders/Unknown", "Folders/Werbung/Sub") for q in box.queries))

    def test_changed_or_missing_is_held_without_mutation(self):
        for changes in ({"missing": True}, {"changed": True}):
            with self.subTest(changes=changes), tempfile.TemporaryDirectory() as state:
                box = Mailbox(**changes)
                result, _ = self.run_sorter(box, state, apply=True)
                self.assertEqual(result["held"], 2)
                self.assertFalse(box.commands)

    def test_certificate_guard_and_native_move(self):
        for changes in ({"certificate": b"wrong"}, {"no_move": True}, {"invalid_uid": True}):
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
            with self.subTest(unusable=repr(unusable)), tempfile.TemporaryDirectory() as state:
                box = Mailbox()
                sorter = worker.Sorter(configuration(True), FakeSecrets(), Path(state), lambda *a, **kw: box)
                with patch.object(classifier, "classify", side_effect=[unusable, "Rechnungen"]):
                    result = sorter.run("partial")
                self.assertEqual((result["unclassified"], result["moved"]), (1, 1))
                self.assertEqual([c[0] for c in box.commands], ["Archive", "Archive"])
                held = [json.loads(line) for line in Path(state, "plan-partial.jsonl").read_text().splitlines()]
                self.assertEqual(held[0]["status"], "model_answer_unusable")
                with patch.object(classifier, "classify") as again:
                    sorter.run("partial-again")
                self.assertEqual(again.call_count, 0)

    def test_held_messages_count_against_the_budget(self):
        with tempfile.TemporaryDirectory() as state:
            box = Mailbox()
            result, calls = self.run_sorter(box, state, verdict="invented", max_messages=1)
            self.assertEqual((result["unclassified"], calls), (1, 1))

    def test_classifier_failure_preserves_mail(self):
        with tempfile.TemporaryDirectory() as state:
            box = Mailbox()
            sorter = worker.Sorter(configuration(True), FakeSecrets(), Path(state), lambda *a, **kw: box)
            with patch.object(classifier, "classify", side_effect=RuntimeError("Model offline")), self.assertRaises(RuntimeError):
                sorter.run("offline")
            self.assertFalse(box.commands)
            self.assertTrue(box.logged_out)

    def test_service_account_read_capture_cache_and_no_leaks(self):
        with tempfile.TemporaryDirectory() as directory, patch.dict(os.environ, {"CREDENTIALS_DIRECTORY": directory}):
            Path(directory, "op-service-account").write_text("test-bootstrap-token", encoding="utf-8")
            secrets = worker.Secrets(configuration())
            with patch.object(worker.subprocess, "run", return_value=SimpleNamespace(returncode=0, stdout="test-password", stderr="")) as run:
                self.assertEqual(secrets.get("passwordRef"), "test-password")
                self.assertEqual(secrets.get("passwordRef"), "test-password")
                self.assertEqual(run.call_count, 1)
                args, kwargs = run.call_args
                self.assertNotIn("test-password", str(args))
                self.assertNotIn("test-bootstrap-token", str(args))
                self.assertEqual(kwargs["env"]["OP_BIOMETRIC_UNLOCK_ENABLED"], "false")
                self.assertTrue(kwargs["capture_output"])
            secrets = worker.Secrets(configuration())
            with patch.object(worker.subprocess, "run", side_effect=subprocess.TimeoutExpired(["op"], 1, output="test-password")):
                with self.assertRaisesRegex(RuntimeError, "^1Password read failed$"):
                    secrets.get("passwordRef")

    def test_http_auth_and_fixed_routes(self):
        app = SimpleNamespace(secrets=FakeSecrets(), previous={"status": "done"}, start=lambda read: {"started": True, "markRead": read})
        server = worker.ThreadingHTTPServer(("127.0.0.1", 0), worker.Handler)
        server.application = app
        thread = threading.Thread(target=server.serve_forever, daemon=True)
        thread.start()
        try:
            for path, token, body, expected in (("/api/tick", "wrong", None, 401), ("/api/tick", "x" * 40, None, 202), ("/api/mark-read", "x" * 40, None, 202), ("/api/tick", "x" * 40, "{\"apply\":true}", 400), ("/untrusted", "x" * 40, None, 404)):
                connection = HTTPConnection("127.0.0.1", server.server_port, timeout=5)
                connection.request("POST", path, body=body, headers={"Authorization": "Bearer " + token})
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
            worker.atomic_json(Path(state) / "status.json", {"id": "previous", "status": "running"})
            app = worker.Application(configuration(), Path(state))
            self.assertEqual(app.previous["status"], "failed")
            app.lock.acquire()
            self.assertEqual(app.start(False), {"started": False, "busy": True})
            app.lock.release()

    def test_scheduled_job_also_marks_existing_mail_without_reclassification(self):
        with tempfile.TemporaryDirectory() as state:
            app = worker.Application(configuration(), Path(state))
            calls = []
            app.sorter = SimpleNamespace(run=lambda run_id, mark_read: calls.append(mark_read) or {"planned": 0, "dryRun": True})
            app.lock.acquire()
            with contextlib.redirect_stdout(io.StringIO()):
                app.finish({"id": "scheduled", "status": "running"}, False)
            self.assertEqual(calls, [False, True])
            self.assertEqual(app.previous["status"], "done")
            self.assertIn("existingRead", app.previous)
            self.assertFalse(app.lock.locked())


if __name__ == "__main__":
    unittest.main()
