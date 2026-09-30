# Recovery installer

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
