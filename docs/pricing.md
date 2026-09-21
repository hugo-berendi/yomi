# Pricing

A summary of the amount I pay for all the subscriptions related to this setup.

Total: 3,50€/month

| Name                                                  | Description                          | Amount (€/year) |
| ------------------------------------------------------ | ------------------------------------- | --------------- |
| [Migadu](https://migadu.com/)                         | Mail                                  | ~19             |
| [Porkbun](https://porkbun.com/)                       | Domain: kamachi.dev                   | ~12             |
| [Porkbun](https://porkbun.com/)                       | Domain: hugo-berendi.de               | ~4              |
| [Backblaze](https://www.backblaze.com/cloud-storage)  | B2 Cloud Storage (off-site backups)   | ~7              |

B2 is billed in USD at $6/TB-month; the row above is sized to inari's ~96 GiB
off-site repository (see `hosts/nixos/inari/services/restic.nix`), not the
Backblaze billing page's own estimate, which still only covers the first few
days since that backup started and understates the steady-state cost.
