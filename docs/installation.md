# Recovery installer

The ISO includes `yomi-recover`, a terminal wizard for Inari's replacement SSD.
On the running server, `nix develop -c just recover` builds the same tool and
opens it with sudo. It does not switch the running system. The older
`scripts/live.sh` interface is documented below.

## Before returning the Beelink

1. Build the ISO with `nix develop -c just build-iso` and write it to an installer
   USB. Keep kagutsuchi, the encrypted key stick, separate. Boot the ISO once and
   check that the menu and your independent recovery identity work.
2. On the running server, open the wizard, unlock kagutsuchi and choose
   **Prepare recovery material**. Use the current checkout and a new bundle
   directory, for example `/raid5pool/backups/inari-migration`. The default age
   identity is `/kagutsuchi/age/yomi-recovery.txt`. Preparation first proves this
   identity can decrypt the boot recovery key and validates that key against ZFS
   without changing the loaded key. It then fetches every locked
   flake input, exports its source to an encrypted NAR archive, saves the checkout,
   and encrypts boot/unlocking keys and Restic credentials. It decrypts each
   artifact to check it. No services are stopped and no disks are formatted.
3. Shut the server down cleanly. Boot the ISO's **beelink-rescue** entry on the old
   Beelink. The normal entry uses all CPUs and is intended for the replacement PC.
   Both entries use Linux 6.12 and ZFS 2.3. Do not upgrade pool features.
4. Run `yomi-recover`. Unlock kagutsuchi and import the retained HDD pool with
   **Read-write for backup and recovery**. Choose **Back up the entire offline
   SSD** and select the Crucial by its model and serial number. The tool refuses
   mounted disks, active swap, imported pools and a destination on the source.
   Type the displayed SSD identity to begin.
5. Keep the server offline until the final backup finishes. The tool captures
   every disk byte in encrypted 1 GiB chunks, then imports only the source SSD's
   ZFS pool without mounting it, takes a recursive snapshot, exports its complete
   raw replication stream and saves the ESP. It exports the source pool again.
   It decrypts and checks every artifact before reporting success.
6. Copy the **entire bundle directory** to another machine, such as the Windows
   PC. Budget about 800 GB for the 500 GB disk image, the separate ZFS stream and
   recovery sources, with extra room for snapshots. The SSD's encrypted contents
   might not compress. On Windows,
   run `powershell -ExecutionPolicy Bypass -File .\Verify-Copy.ps1` from the copy.
   This checks the encrypted files against `checksums.json`; it proves transfer
   integrity, not decryption or bootability. Return to the ISO and verify that
   copy with **Verify a backup**, using the independent identity from kagutsuchi.
   Ideally, restore to a spare SSD and boot it before returning the original.

For the Windows transfer, create an SMB share on that PC with enough free space.
The wizard's **Connect to a Windows backup share** asks for its address, share and
username, then requests the password without echoing it. It mounts the share at
`/media/windows-backup`. Choose **Copy a verified bundle** and select a directory
there. The tool transfers encrypted artifacts and decrypts the destination copy
to verify it. A mounted external disk also works as a destination. Keep backup
mounts outside `/mnt`, where the replacement installation is mounted.

The final authenticated manifest is `manifest.json.age`. `work.json` is a progress
checkpoint, not proof of a completed backup. Incomplete chunks end in `.partial`.
Image backup retries re-read completed source chunks until the image has been
captured. After the tool starts ZFS replication, retries retain that image and
repeat replication from the saved snapshot. Do not boot the old installation or
write to its SSD between attempts. Start a new bundle if you do.

## On the replacement PC

Boot the ISO's normal entry, reconnect **all three** HDDs and kagutsuchi, and run
`yomi-recover`. Import the HDD pool read-write for recovery journals. That action
imports the existing pool; it never creates one or formats its disks. The root
pool on the replacement SSD is separate.

Choose **Disko + ZFS restore + NixOS installation**. Select the bundle and the new
SSD, choose its LAN interface, optionally select a Wi-Fi interface for hostapd,
and choose manual or TPM unlocking. Use **New PC** to disable the Beelink CPU
containment. Confirm the target using its displayed serial or WWN.

The tool verifies and decrypts the entire bundle and imports the archived flake
sources before formatting. The ISO contains Disko's prebuilt destroy and format
scripts with their dependencies. It selects their target before asking for disk
confirmation. Raw encrypted ZFS cannot overwrite a fresh
encrypted root, so Disko creates a plain parent pool and the stream is received
as `zroot/recovered`. The tool preserves `@blank`, restores `/boot`, loads the
original encryption key, regenerates hardware configuration and installs NixOS.
TPM mode seals that key to the replacement's TPM with PCR 7; the independent
age-encrypted recovery key remains available. A changed configuration can still
need internet access to binary caches, even though private Git access is removed
from this restore path.

The wizard saves the adapted checkout in `/persist/state/etc/yomi`, including
`hosts/nixos/inari/recovery-local.nix`. **Use that checkout for subsequent
rebuilds** until its hardware choices have been reviewed and merged into your
regular checkout. It records the dataset prefix, target SSD/ESP, network
interfaces, TPM choice and Beelink workaround choice. Rollback and Sanoid use the
restored dataset prefix too.

Inspect the installation, then choose **Unmount and export the recovered SSD**
before rebooting. Do not run another Disko formatting command over it.

**Restore the exact SSD image** preserves every original disk byte and skips
Disko. It requires at least the original capacity in bytes and the same logical
sector size. It verifies the backup before writing and reads every restored
chunk back. Retrying it validates completed target chunks before skipping them.
Afterward choose **Adapt an existing installation** to install the new hardware
configuration and reseal the key before booting. The exact image leaves extra
space on a larger SSD unused; the Disko/ZFS route uses the replacement's capacity.

The wizard also offers a fresh Inari installation, disk inspection, retained-pool
import and a rescue shell. Fresh installation needs a checkout, cold input
access and Inari's install-time keys on kagutsuchi. The ISO's checkout is
`/iso/yomi`. Fresh installation restores no user data.

## Interrupted operations

An image restore can be rerun with the same target and bundle. It checks the
recorded target identity and revalidates each completed chunk. Separate disk
locks prevent two recovery commands from writing the same disk.

A ZFS restore writes `zfs-restore.json` before partitioning. If receiving finished
but installation failed, choose **Continue installation**. It checks the target
identity and mounts the existing restored datasets without formatting. A failure
during partitioning or receiving stops for inspection in the rescue shell. It
never guesses that wiping the disk again is safe. After inspecting it, an
intentional restart requires releasing/exporting the target and moving the old
ZFS restore journal aside before selecting the restore workflow again.

## Verification

`nix build --no-link .#checks.x86_64-linux.recover-tool` exercises real encryption,
authenticated manifests, tamper rejection, wrong keys, incomplete producers,
path validation, disk guards and locks. `recover-disks` boots a disposable NixOS
VM and uses real GPT, FAT, encrypted ZFS, Disko and virtual disks. It checks the
whole-disk image, read-back, repeat image restores, smaller-target rejection,
HDD-pool protection, raw ZFS restoration and preservation of encryption and
`@blank`. These checks do not prove your real TPM, network or application health
on the replacement PC.

## Older command-line installer

Run `scripts/live.sh <host> <mode> [action]` as root from the installation
environment. The script finds its checkout independently of the current working
directory. A host needs a checked-in Disko partition file and a hardware directory.
WSL and the ISO are not installation targets for this script.

`mount` mounts an existing layout. `disko` partitions and formats the disks named
in that host's partition file. Inspect that file and verify the target disk
identity before running it. The optional `install` action generates hardware
configuration and installs NixOS; `enter` opens the mounted system.

Before opening the key device or running Disko, the script archives every locked
flake input. This makes a fetch or authentication failure stop before disk changes.
Disko itself comes from the checkout's locked input rather than a global registry.
Required command failures propagate, and success is printed only after cleanup.
Hardware generation uses a temporary file and stages only `generated.nix`.

The `skills` input is a private SSH repository. A fresh ISO needs an SSH identity
with access to it, reachable forge DNS/networking, and the correct host key. Test
the fetch as the same user that will run the installer:

```sh
nix flake archive --no-write-lock-file --accept-flake-config
```

A successful fetch on an existing host with a populated Nix store does not prove
that a fresh ISO can fetch it. A cold ISO installation remains a separate check.
If the required SSH identity lives on kagutsuchi, open the stick manually and load
that identity before the fetch. The installer leaves an already-mounted stick
open; close it manually when finished. A stick opened by the installer is closed
on normal exit, a required command failure, or an interrupt.

Run the disk-free control-flow regression with
`nix build --no-link .#checks.x86_64-linux.installer`. It substitutes commands and
mount paths in a disposable checkout. It tests invalid arguments, failed fetches,
unlock/Disko/install failures, atomic hardware generation, scoped Git staging and
key-device cleanup. It does not partition disks or test a complete installation.
