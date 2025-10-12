# YubiKey Setup Guide

This guide covers integrating a YubiKey with the Yomi NixOS configuration for:
- **AGE encryption/decryption** with YubiKey-backed keys
- **U2F authentication** for sudo, login, and polkit
- **SSH authentication** via GPG agent with PIV
- **Smart card support** and touch detection

## Prerequisites

- YubiKey 5 series or newer (supports PIV and FIDO2/U2F)
- Physical access to the YubiKey
- Admin/sudo access to configure the system

## 1. AGE Encryption Setup

### Generate YubiKey AGE Recipient

```bash
age-plugin-yubikey --generate
```

This will:
1. Prompt you to touch your YubiKey
2. Output an AGE recipient ID like: `age1yubikey1q2w3e4r5t6y7u8i9o0p...`

**Save this recipient ID** - you'll need it for configuration.

### Test Encryption/Decryption

```bash
echo "test secret" | rage -r age1yubikey1... -o test.age
rage -d -i age-plugin-yubikey test.age
```

You should be prompted to touch your YubiKey during both operations.

## 2. U2F Authentication Setup

### Enroll YubiKey for U2F

```bash
mkdir -p ~/.config/Yubico
pamu2fcfg -o pam://yomi > ~/.config/Yubico/u2f_keys
```

**Important**: Use `pam://yomi` as the appId. This allows U2F keys to work across multiple devices with the same configuration.

### For Multiple Keys

Append additional keys to the same file:

```bash
pamu2fcfg -o pam://yomi -n >> ~/.config/Yubico/u2f_keys
```

### Store in sops

Create `hosts/nixos/common/secrets/u2f_keys.yaml`:

```yaml
yubikey/u2f_keys: |
  username:KEY_HANDLE_1,KEY_HANDLE_2,...
```

Encrypt with sops:

```bash
sops -e hosts/nixos/common/secrets/u2f_keys.yaml > hosts/nixos/common/u2f_keys.yaml
```

## 3. GPG/SSH Setup

### Initialize GPG Card

```bash
gpg --card-edit
> admin
> passwd
> quit
```

Set your PIN and Admin PIN.

### Generate Authentication Key (PIV)

```bash
gpg --expert --full-gen-key
```

Select:
- Key type: RSA and RSA
- Key size: 4096
- Expiration: 0 (does not expire) or your preference

Move the key to YubiKey:

```bash
gpg --edit-key YOUR_KEY_ID
> keytocard
> save
```

### Export SSH Public Key

```bash
gpg --export-ssh-key YOUR_KEY_ID > ~/.ssh/yubikey.pub
ssh-add -L  # Verify the key is available
```

Add the public key to remote servers:

```bash
ssh-copy-id -i ~/.ssh/yubikey.pub user@host
```

## 4. Configure YubiKey Module

Edit your host configuration (e.g., `hosts/nixos/amaterasu/default.nix`):

```nix
{
  yomi.yubikey = {
    enable = true;
    users = ["pilot"];  # Your username
    
    pam = {
      u2f = {
        enable = true;
        appId = "pam://yomi";
        secretPath = ../common/u2f_keys.yaml;
      };
      
      # Optional: Challenge-response mode
      challengeResponse = {
        enable = false;  # Only if you configured challenge-response
        ids = ["30636315"];  # YubiKey serial number
      };
    };
    
    ssh = {
      enableAgent = true;
      publicKeys = ["67D63C5F40CC55DA"];  # From gpg --list-secret-keys
    };
    
    age = {
      enable = true;
      recipients = [
        "age1yubikey1q2w3e4r5t6y7u8i9o0p..."  # From step 1
      ];
    };
    
    touchDetector.enable = true;
    lockOnRemoval.enable = true;
  };
}
```

## 5. Home Manager Configuration

The module automatically configures GPG agent for users listed in `yomi.yubikey.users`. 

If you need custom GPG configuration, add to your home-manager config:

```nix
programs.gpg.publicKeys = [
  {
    source = ./yubikey_pub;  # Export with: gpg --export YOUR_KEY_ID > yubikey_pub
    trust = "ultimate";
  }
];
```

## 6. Rebuild and Test

```bash
just nixos-rebuild switch
```

### Test U2F Authentication

```bash
sudo echo "test"
```

You should be prompted to touch your YubiKey.

### Test SSH

```bash
ssh-add -L  # Should show your YubiKey SSH key
ssh user@host  # Touch YubiKey when prompted
```

### Test AGE Encryption

```bash
yk-enc secret.txt
yk-decrypt secret.txt.age
```

## 7. Using Helper Scripts

The `yk-enc` and `yk-decrypt` scripts are automatically available when you enable the YubiKey module (provided via home-manager).

### `yk-enc` - Encrypt with YubiKey

```bash
yk-enc secret.txt
yk-enc -o encrypted.age secret.txt
yk-enc -r age1yubikey1... -a secret.txt  # ASCII armor
```

Uses `$YOMI_YUBI_AGE_RECIPIENTS` by default (set by the module).

### `yk-decrypt` - Decrypt with YubiKey

```bash
yk-decrypt secret.txt.age
yk-decrypt -o output.txt secret.age
yk-decrypt secret.age > output.txt
```

## Troubleshooting

### YubiKey Not Detected

```bash
gpg --card-status
pcsc_scan
```

Ensure `pcscd.service` is running:

```bash
systemctl status pcscd
```

### U2F Not Working

Check mapping file:

```bash
cat ~/.config/Yubico/u2f_keys
```

Verify PAM configuration:

```bash
grep -r u2f /etc/pam.d/
```

### SSH Agent Not Using YubiKey

```bash
echo $SSH_AUTH_SOCK  # Should point to GPG socket
gpg-connect-agent /bye
```

### AGE Plugin Not Found

```bash
which age-plugin-yubikey
age-plugin-yubikey --list
```

## Advanced: Multiple YubiKeys

To use multiple YubiKeys for redundancy:

1. Generate AGE recipients on each key
2. Enroll each key for U2F (append to `u2f_keys`)
3. Add all recipients to `yomi.yubikey.age.recipients`

```nix
age.recipients = [
  "age1yubikey1aaaa..."  # YubiKey 1
  "age1yubikey1bbbb..."  # YubiKey 2
];
```

When encrypting, files will be encrypted to all recipients. Any key can decrypt.

## Security Notes

- **PIN Protection**: Set a strong PIN/Admin PIN on your YubiKey
- **Backup Keys**: Generate a backup AGE key for emergency access
- **Physical Security**: YubiKeys are physical tokens - keep them secure
- **Touch Requirement**: Most operations require physical touch (can't be automated maliciously)
- **Revocation**: If a YubiKey is lost, remove it from U2F mappings and re-encrypt secrets

## References

- [age-plugin-yubikey Documentation](https://github.com/str4d/age-plugin-yubikey)
- [YubiKey PIV Guide](https://developers.yubico.com/PIV/)
- [pam-u2f Documentation](https://developers.yubico.com/pam-u2f/)
