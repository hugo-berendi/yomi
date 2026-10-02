{
  pkgs,
  package,
}:
pkgs.testers.runNixOSTest {
  name = "yomi-recover-disks";
  nodes.machine = {pkgs, ...}: {
    virtualisation = {
      memorySize = 4096;
      cores = 2;
      diskSize = 8192;
      emptyDiskImages = [2048 3072 512];
    };
    networking.hostId = "1234abcd";
    boot.supportedFilesystems = ["zfs"];
    boot.kernelPackages = pkgs.linuxPackages_6_12;
    boot.zfs.package = pkgs.zfs_2_3;
    boot.zfs.forceImportRoot = false;
    boot.extraModprobeConfig = "options zfs zfs_arc_max=134217728";
    environment.systemPackages = [package pkgs.python3 pkgs.age pkgs.zstd pkgs.gptfdisk pkgs.dosfstools];
    environment.etc."recover.py".source = ../pkgs/yomi-recover/recover.py;
  };
  testScript = ''
    start_all()
    machine.wait_for_unit("multi-user.target")
    machine.succeed("mkdir -p /backup /source /run/fixture; age-keygen -o /run/identity")
    machine.succeed("printf 'independent-fixture-disk-key' > /run/disk.key")
    machine.succeed("sgdisk -n 1:1MiB:+512MiB -t 1:ef00 -n 2:0:0 /dev/vdb; mkfs.vfat /dev/vdb1")
    machine.succeed("zpool create -f -R /source -o compatibility=openzfs-2.3-linux -O mountpoint=/ -O encryption=aes-256-gcm -O keyformat=passphrase -O keylocation=file:///run/disk.key zroot /dev/vdb2")
    machine.succeed("zfs snapshot zroot@blank")
    for name, mount in [("root/local/nix", "/nix"), ("root/local/cache", "/persist/local/cache"), ("root/persist/data", "/persist/data"), ("root/persist/state", "/persist/state")]:
        machine.succeed(f"zfs create -p -o mountpoint={mount} zroot/{name}")
    machine.succeed("mkdir -p /source/boot; mount /dev/vdb1 /source/boot; age -r $(age-keygen -y /run/identity) -o /source/boot/zroot-recovery-key.age /run/disk.key")
    machine.succeed("python3 -c 'import sys; sys.path.insert(0, \"/etc\"); import recover; recover.check_recovery_key(\"/run/identity\", \"/source/boot/zroot-recovery-key.age\", \"zroot\")'")
    machine.succeed("printf 'persisted sentinel' > /source/persist/data/sentinel; printf 'state sentinel' > /source/persist/state/sentinel")
    machine.succeed("python3 -c 'import sys; sys.path.insert(0, \"/etc\"); import recover; from pathlib import Path; recover.atomic_json(Path(\"/backup/work.json\"), {\"format\": 1, \"complete\": False, \"image\": [], \"artifacts\": {}, \"recipient\": recover.recipient(\"/run/identity\")})'")
    machine.fail("yomi-recover backup --source /dev/vdb --bundle /backup --identity /run/identity --confirm vdb")
    machine.succeed("umount /source/boot; zpool export zroot; sha256sum /dev/vdb | cut -d' ' -f1 > /run/original.sha")
    machine.succeed("yomi-recover backup --source /dev/vdb --bundle /backup --identity /run/identity --confirm vdb", timeout=600)
    machine.succeed("yomi-recover verify --bundle /backup --identity /run/identity", timeout=600)
    machine.fail("yomi-recover backup --source /dev/vdb --bundle /backup --identity /run/identity --confirm vdb")
    machine.fail("yomi-recover restore-image --target /dev/vdd --bundle /backup --identity /run/identity --confirm vdd", timeout=600)
    machine.succeed("yomi-recover restore-image --target /dev/vdc --bundle /backup --identity /run/identity --confirm vdc", timeout=600)
    machine.succeed("head -c 2147483648 /dev/vdc | sha256sum | cut -d' ' -f1 | cmp - /run/original.sha")
    machine.succeed("yomi-recover restore-image --target /dev/vdc --bundle /backup --identity /run/identity --confirm vdc", timeout=600)
    machine.succeed("zpool create -f -O mountpoint=none raid5pool /dev/vdd")
    machine.fail("yomi-recover restore-image --target /dev/vdd --bundle /backup --identity /run/identity --confirm vdd", timeout=600)
    machine.succeed("yomi-recover restore-zfs --target /dev/vdc --bundle /backup --identity /run/identity --confirm vdc --no-install", timeout=600)
    machine.succeed("test $(findmnt -n -o SOURCE --mountpoint /mnt) = zroot/recovered; grep -q 'persisted sentinel' /mnt/persist/data/sentinel; grep -q 'state sentinel' /mnt/persist/state/sentinel")
    machine.succeed("zfs list -t snapshot zroot/recovered@blank; test $(zfs get -H -o value encryptionroot zroot/recovered/root/persist/state) = zroot/recovered")
    machine.fail("yomi-recover restore-zfs --target /dev/vdc --bundle /backup --identity /run/identity --confirm vdc --no-install", timeout=600)
    machine.succeed("zpool status raid5pool; test $(zfs get -H -o value mountpoint raid5pool) = none")
    machine.succeed("zpool status -LP zroot | grep -q /dev/vdc2")
    machine.succeed("yomi-recover release-target --target /dev/vdc --confirm vdc")
    machine.fail("zpool list zroot")
    machine.fail("findmnt --mountpoint /mnt")
    machine.succeed("zpool status raid5pool")
    machine.succeed("zpool import -N -d /dev/vdb2 zroot")
    machine.fail("zfs list zroot/recovered")
    machine.succeed("zpool export zroot")
  '';
}
