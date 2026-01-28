# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

Single-host NixOS configuration using flakes for a home NAS server (hostname: `nwa`). The system runs ZFS storage, media services, file sharing, and various home server applications.

## Build Commands

```bash
# Rebuild and switch to new configuration
sudo nixos-rebuild switch --flake /home/dolf/.config/nixos

# Build without switching (test compilation)
sudo nixos-rebuild build --flake /home/dolf/.config/nixos

# Check flake for errors
nix flake check

# Update flake dependencies
nix flake update

# Edit encrypted secrets
sops secrets/secrets.yaml
```

## Architecture

**Flake Inputs:** nixpkgs (unstable), nixarr (media stack), nixvim (editor), sops-nix (secrets)

**Module Organization:**
- `flake.nix` — Entry point, defines `nwa` host and sets `allowUnfree`
- `common/` — Shared modules (fish shell, nixvim, tailscale)
- `hosts/nwa/` — Host-specific configuration modules

**Host Modules (`hosts/nwa/`):**
- `configuration.nix` — Core system: boot, hardware, networking, users, packages
- `hardware-configuration.nix` — Auto-generated, do not edit manually
- `zfs.nix` — ZFS pools (rpool, tank), sanoid snapshots, ZED notifications via ntfy.sh
- `media.nix` — nixarr stack: Plex, Jellyfin, Transmission, Sonarr, Radarr, Lidarr, Bazarr, Prowlarr, Recyclarr
- `samba.nix` — SMB shares with Time Machine support (uses `mkShare`/`mkTimeMachineShare` helpers)
- `incus.nix` — Container/VM virtualization with ZFS-backed storage
- `power.nix` — PowerTOP, Intel P-state, HDD spindown, NIC power management fix
- `syncthing.nix` — File sync with remote devices
- `gatus.nix` — Status page with ntfy.sh alerts (uses `mkEndpoint` helper)
- `jellyplex-watched.nix` — Sync watch status between Jellyfin and Plex
- `services.nix` — Simple services: AdGuard Home, Mealie, Scrutiny

## Secrets Management

Uses sops-nix with age encryption. Key at `/home/dolf/.config/sops/age/keys.txt`.

Secrets in `secrets/secrets.yaml` are referenced via `config.sops.placeholder.<key>` for runtime substitution in templates.

## Key Patterns

- Services organized as individual `.nix` files imported by `hosts/nwa/default.nix`
- Helper functions reduce repetition (e.g., `mkEndpoint` in gatus.nix, `mkShare` in samba.nix)
- ZFS primary storage with dual boot mirrors (/boot1, /boot2)
- Network bridge `br0` on `eno2` with nftables
- Conventional commits: `feat:`, `fix:`, `chore:`, `refactor:`
