{lib, ...}: {
  yomi.inari.rootDataset = lib.mkForce "zroot/recovered";
  yomi.inari.tpmUnlock = lib.mkForce true;
  yomi.inari.lanInterface = lib.mkForce "eno1";
  disko.devices.disk.x.device = lib.mkForce "/dev/disk/by-id/nvme-CT500P3PSSD8_240546B2A109";
  fileSystems."/boot".device = lib.mkForce "/dev/disk/by-id/nvme-CT500P3PSSD8_240546B2A109-part1";
}
