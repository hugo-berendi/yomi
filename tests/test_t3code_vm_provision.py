import hashlib
import tempfile
import unittest
from pathlib import Path
from unittest import mock

import importlib.util


MODULE = Path(__file__).parents[1] / "hosts/nixos/inari/services/t3code-vm/provision.py"
SPEC = importlib.util.spec_from_file_location("t3code_vm_provision", MODULE)
provision = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(provision)


class ProvisionTests(unittest.TestCase):
    def test_download_is_checksum_checked_and_idempotent(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            source = root / "source"
            source.write_bytes(b"ubuntu")
            destination = root / "image"
            digest = hashlib.sha256(b"ubuntu").hexdigest()
            with mock.patch.object(provision.urllib.request, "urlretrieve") as fetch:
                fetch.side_effect = lambda _url, target: Path(target).write_bytes(
                    source.read_bytes()
                )
                self.assertTrue(
                    provision.download_image(
                        "https://example.invalid/image", digest, destination
                    )
                )
                self.assertFalse(
                    provision.download_image(
                        "https://example.invalid/image", digest, destination
                    )
                )
                fetch.assert_called_once()

    def test_existing_disk_and_seed_are_never_overwritten(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            image = root / "image"
            image.write_bytes(b"base")
            disk = root / "root.qcow2"
            disk.write_bytes(b"existing")
            seed = root / "seed.iso"
            seed.write_bytes(b"existing-seed")
            user_data = root / "user-data"
            user_data.write_text("key=__MANAGEMENT_PUBLIC_KEY__")
            network = root / "network"
            network.write_text("network")
            metadata = root / "metadata"
            metadata.write_text("metadata")
            key = root / "key"
            key.write_text("ssh-ed25519 AAAA test\n")
            with mock.patch.object(provision.subprocess, "run") as run:
                self.assertFalse(provision.ensure_disk(image, disk, "80G", "qemu-img"))
                with self.assertRaises(ValueError):
                    provision.render_seed(
                        user_data, network, metadata, key, seed, "cloud-localds"
                    )
                run.assert_not_called()
            self.assertEqual(disk.read_bytes(), b"existing")
            self.assertEqual(seed.read_bytes(), b"existing-seed")

    def test_seed_renders_runtime_management_key(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            user_data = root / "user-data"
            user_data.write_text("key=__MANAGEMENT_PUBLIC_KEY__")
            network = root / "network"
            network.write_text("network")
            metadata = root / "metadata"
            metadata.write_text("metadata")
            key = root / "key"
            key.write_text("ssh-ed25519 AAAA runtime\n")
            seed = root / "seed.iso"
            with mock.patch.object(provision.subprocess, "run") as run:

                def make_seed(command, check):
                    Path(command[2]).write_bytes(Path(command[3]).read_bytes())

                run.side_effect = make_seed
                self.assertTrue(
                    provision.render_seed(
                        user_data, network, metadata, key, seed, "cloud-localds"
                    )
                )
            self.assertTrue(seed.exists())
            self.assertIn(b"runtime", seed.read_bytes())
            with mock.patch.object(provision.subprocess, "run") as run:
                self.assertFalse(
                    provision.render_seed(
                        user_data, network, metadata, key, seed, "cloud-localds"
                    )
                )
                run.assert_not_called()
                user_data.write_text("changed key=__MANAGEMENT_PUBLIC_KEY__")
                with self.assertRaises(ValueError):
                    provision.render_seed(
                        user_data, network, metadata, key, seed, "cloud-localds"
                    )


if __name__ == "__main__":
    unittest.main()
