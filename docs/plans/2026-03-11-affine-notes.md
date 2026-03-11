# AFFiNE Notes Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Deploy self-hosted AFFiNE on `inari` at `notes.hugo-berendi.de` with Pocket ID OIDC support and a homepage dashboard entry.

**Architecture:** Run AFFiNE as an OCI-container stack on `inari` with separate app, migration, Postgres, and Valkey containers on a dedicated Docker network. Expose the app through `yomi.cloudflared.at.notes`, persist container data under `/persist/state`, and preseed AFFiNE's config with OIDC settings using a generated `config.json` plus secret-backed environment file.

**Tech Stack:** NixOS modules, sops-nix, Docker OCI containers, Cloudflared, Pocket ID OIDC, Homepage Dashboard

---

### Task 1: Add AFFiNE service port and import

**Files:**
- Modify: `modules/nixos/ports.nix`
- Modify: `hosts/nixos/inari/default.nix`

**Step 1: Add `affine` to the known service ports**

Insert `"affine"` into `knownServices` in `modules/nixos/ports.nix`.

**Step 2: Import the new service module**

Add `./services/affine.nix` to `hosts/nixos/inari/default.nix` imports.

**Step 3: Verify formatting mentally before continuing**

Keep fold markers and alphabetical-neighbor style consistent with nearby services.

### Task 2: Add AFFiNE OCI service module

**Files:**
- Create: `hosts/nixos/inari/services/affine.nix`

**Step 1: Define service locals**

Add a `let` block for:
- AFFiNE host/url via `config.yomi.cloudflared.at.notes`
- persistent paths for storage, config, and Postgres data
- container names/network name
- OIDC issuer URL from Pocket ID

**Step 2: Add reverse proxy/tunnel config**

Set `yomi.cloudflared.at.notes = { port = config.yomi.ports.affine; subdomain = "notes"; };`.

**Step 3: Add sops-backed secrets/templates**

Declare secrets for:
- `affine_db_password`
- `affine_oidc_client_id`
- `affine_oidc_client_secret`
- `affine_app_key`

Generate templates for:
- `affine.env` containing DB URL, AFFiNE host settings, and private key
- `affine-config.json` containing OIDC provider config and server name

**Step 4: Add persistent directories and tmpfiles**

Create directories for AFFiNE storage/config/Postgres and mark them for persistence under `/persist/state`.

**Step 5: Add Docker network unit**

Create a systemd oneshot service that ensures a dedicated Docker network exists, following the `anonaddy.nix` pattern.

**Step 6: Define Postgres and Valkey containers**

Add OCI containers for:
- `affine-postgres` using `pgvector/pgvector:pg16`
- `affine-valkey` using `valkey/valkey:alpine`

Mount persistent storage and attach both to the dedicated network.

**Step 7: Define migration and app containers**

Add OCI containers for:
- `affine-migration` running `node ./scripts/self-host-predeploy.js`
- `affine` serving port 3010

Mount config/storage volumes, use the generated env file, and set dependencies on DB/Valkey/migration as needed.

**Step 8: Add service ordering overrides**

Add systemd service overrides so the Docker network exists before AFFiNE containers start and the app waits for migration.

### Task 3: Add homepage entry

**Files:**
- Modify: `hosts/nixos/inari/services/homepage.nix`

**Step 1: Add AFFiNE card under Tooling**

Add a new Tooling service entry:
- name: `AFFiNE`
- href: `https://notes.hugo-berendi.de`
- description: `Knowledge base, docs, whiteboards`

### Task 4: Add secrets placeholder entries

**Files:**
- Modify: `hosts/nixos/inari/secrets.yaml`

**Step 1: Add encrypted secret entries for new AFFiNE secrets**

Add entries for:
- `affine_db_password`
- `affine_oidc_client_id`
- `affine_oidc_client_secret`
- `affine_app_key`

### Task 5: Verify the configuration

**Files:**
- Test: `hosts/nixos/inari/services/affine.nix`
- Test: `modules/nixos/ports.nix`
- Test: `hosts/nixos/inari/services/homepage.nix`

**Step 1: Build inari**

Run: `just nixos-rebuild build inari`
Expected: build succeeds with no Nix evaluation errors.

**Step 2: Run lint**

Run: `just lint`
Expected: formatting checks pass.

**Step 3: Review final diff**

Confirm only AFFiNE-related changes plus the dashboard entry are present.
