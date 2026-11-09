import copy
import unittest

from signal_unix import self_note, validate_send


class SignalBoundaryTests(unittest.TestCase):
    account = "+491234567890"

    def note(self):
        return {
            "account": self.account,
            "envelope": {
                "sourceNumber": self.account,
                "syncMessage": {
                    "sentMessage": {
                        "destinationNumber": self.account,
                        "timestamp": 123,
                        "message": "Please investigate the login",
                    }
                },
            },
        }

    def test_accepts_only_own_text_note(self):
        note = self.note()
        self.assertEqual(self_note(note, self.account), note)
        for mutate in (
            lambda n: n.update(account="+499999999999"),
            lambda n: n["envelope"].update(sourceNumber="+499999999999"),
            lambda n: n["envelope"].pop("syncMessage"),
            lambda n: n["envelope"]["syncMessage"]["sentMessage"].update(
                destinationNumber="+499999999999"
            ),
            lambda n: n["envelope"]["syncMessage"]["sentMessage"].update(
                groupInfo={"groupId": "private-group"}
            ),
            lambda n: n["envelope"]["syncMessage"]["sentMessage"].update(
                attachments=[{"id": "attachment"}]
            ),
        ):
            candidate = copy.deepcopy(note)
            mutate(candidate)
            self.assertIsNone(self_note(candidate, self.account))

    def test_malformed_events_fail_closed(self):
        for value in (None, [], {}, {"envelope": None}, {"envelope": []}):
            self.assertIsNone(self_note(value, self.account))

    def test_outbound_cannot_contact_others_or_read_local_files(self):
        request = {
            "jsonrpc": "2.0",
            "id": "send-1",
            "method": "send",
            "params": {
                "account": self.account,
                "recipient": [self.account],
                "message": "Done",
            },
        }
        self.assertEqual(validate_send(request, self.account), request)
        for params in (
            {"recipient": ["+499999999999"]},
            {"groupId": "private-group"},
            {"attachments": ["/etc/passwd"]},
            {"account": "+499999999999"},
        ):
            candidate = copy.deepcopy(request)
            candidate["params"].update(params)
            with self.assertRaises(ValueError):
                validate_send(candidate, self.account)
        request["method"] = "listContacts"
        with self.assertRaises(ValueError):
            validate_send(request, self.account)


if __name__ == "__main__":
    unittest.main()
