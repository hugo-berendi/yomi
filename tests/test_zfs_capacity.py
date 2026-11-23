"""The audit's migration snapshot must remain visible even after Nix GC."""

import importlib.util
from pathlib import Path
import unittest

spec = importlib.util.spec_from_file_location(
    "capacity",
    Path(__file__).resolve().parents[1] / "hosts/nixos/inari/services/zfs/capacity.py",
)
capacity = importlib.util.module_from_spec(spec)
spec.loader.exec_module(capacity)


class CapacityTests(unittest.TestCase):
    def test_audit_snapshot_and_boot_baseline(self):
        def run(args):
            if args[0] == "zpool":
                return "zroot\t96\nraid5pool\t30\n"
            return (
                "zroot/recovered@blank\t0\t1024\n"
                "zroot/recovered/root/local/nix@yomi-migration-20261003T104439Z\t100\t101683350733\n"
                "zroot/recovered/root/persist/state@autosnap_daily\t100\t42\n"
            )

        metrics = capacity.collect(run, 2000000)
        self.assertIn('yomi_zfs_pool_capacity_percent{pool="zroot"} 96', metrics)
        self.assertIn("1999900", metrics)
        self.assertIn("101683350733", metrics)
        self.assertNotIn("@blank", metrics)
        self.assertNotIn("autosnap_daily", metrics)
        self.assertIn("last_success_timestamp_seconds 2000000", metrics)

    def test_no_pools_is_failure(self):
        with self.assertRaises(RuntimeError):
            capacity.collect(lambda _: "", 100)

    def test_failed_snapshot_read_does_not_publish_success(self):
        def run(args):
            if args[0] == "zpool":
                return "zroot\t80\n"
            raise RuntimeError("ZFS unavailable")

        with self.assertRaises(RuntimeError):
            capacity.collect(run, 100)


if __name__ == "__main__":
    unittest.main()
