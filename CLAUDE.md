# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

Single-host NixOS configuration using flakes for a home NAS server (hostname: `nwa`). The system runs ZFS storage, media services, file sharing, and various home server applications. Structured to support multiple hosts.

## Build Commands

```bash
# Check flake for errors (no sudo required)
nix flake check

# Rebuild and switch to new configuration
sudo nixos-rebuild switch --flake /home/dolf/.config/nixos

# Build without switching (test compilation)
sudo nixos-rebuild build --flake /home/dolf/.config/nixos

# Update flake dependencies
nix flake update --flake /home/dolf/.config/nixos

# Edit encrypted secrets
sops secrets/secrets.yaml
```

**Important:** Always run `nix flake check` after making changes and before asking the user to rebuild. This catches syntax errors without requiring sudo.

## Architecture

**Flake Inputs:** nixpkgs (unstable), nixarr (media stack), nixvim (editor), sops-nix (secrets)

**Directory Structure:**
```
├── flake.nix              # Entry point, host definitions, allowUnfree
├── common/                # Shell/editor config (all hosts)
│   ├── fish.nix
│   ├── nixvim.nix
│   └── tailscale.nix
├── modules/               # NAS service modules (shareable)
│   ├── frame-art-changer.nix
│   ├── gatus.nix
│   ├── jellyplex-watched.nix
│   ├── media.nix
│   ├── samba.nix
│   ├── services.nix
│   └── syncthing.nix
├── hosts/
│   ├── common.nix         # Shared host config (users, packages, locale, sops)
│   └── nwa/               # Physical NAS host
│       ├── configuration.nix      # Boot, hardware, networking
│       ├── hardware-configuration.nix
│       ├── incus.nix
│       ├── power.nix
│       └── zfs.nix
└── secrets/
    └── secrets.yaml
```

**Module Categories:**
- `common/` — Shell, editor, VPN (inherited by all hosts)
- `hosts/common.nix` — Users, packages, locale, sops (inherited by all hosts)
- `modules/` — NAS services (can be selectively imported per host)
- `hosts/<name>/` — Hardware-specific config (boot, disks, networking)

## Secrets Management

Uses sops-nix with age encryption. Key at `/home/dolf/.config/sops/age/keys.txt`.

Secrets in `secrets/secrets.yaml` are referenced via `config.sops.placeholder.<key>` for runtime substitution in templates.

## Key Patterns

- Helper functions reduce repetition (e.g., `mkEndpoint` in gatus.nix, `mkShare` in samba.nix)
- Hardware-specific config stays in `hosts/<name>/`, services go in `modules/`
- ZFS primary storage with dual boot mirrors (/boot1, /boot2)
- Network bridge `br0` on `eno2` with nftables
- Conventional commits: `feat:`, `fix:`, `chore:`, `refactor:`

## Adding a New Host

1. Create `hosts/<name>/` directory
2. Add `hardware-configuration.nix` (generate with `nixos-generate-config`)
3. Add `configuration.nix` with host-specific boot/hardware/networking
4. Add `default.nix` importing common configs and desired modules
5. Add host to `flake.nix` under `nixosConfigurations`
