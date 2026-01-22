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
- `flake.nix` — Entry point defining the `nwa` host configuration
- `common/` — Shared modules (fish shell, nixvim, tailscale)
- `hosts/nwa/` — Host-specific configuration modules

**Host Modules (`hosts/nwa/`):**
- `configuration.nix` — Core system: boot (GRUB/ZFS), networking (bridge br0), users, localization
- `hardware-configuration.nix` — Auto-generated, do not edit manually
- `zfs.nix` — ZFS pools (rpool, tank), sanoid snapshots, ZED notifications via ntfy.sh
- `media.nix` — nixarr stack: Plex, Transmission, Sonarr, Radarr, Lidarr, Bazarr, Prowlarr
- `samba.nix` — SMB shares with Time Machine support for macOS clients
- `incus.nix` — Container virtualization with ZFS-backed storage
- `power.nix` — PowerTOP, Intel P-state, HDD spindown, USB autosuspend
- `syncthing.nix` — File sync with remote devices (gza, rza, LittleRedRabbit)
- `adguardhome.nix`, `homepage.nix`, `scrutiny.nix` — Dashboard and monitoring services

## Secrets Management

Uses sops-nix with age encryption. Key at `/home/dolf/.config/sops/age/keys.txt`.

Secrets in `secrets/secrets.yaml` are referenced via `config.sops.placeholder.<key>` for runtime substitution.

## Key Patterns

- Services organized as individual `.nix` files imported by `hosts/nwa/default.nix`
- ZFS is the primary storage with dual boot mirrors (/boot1, /boot2)
- Network uses bridge interface `br0` on `eno2` with nftables firewall
- Conventional commits: `feat:`, `fix:`, `chore:`, `BREAKING CHANGE:`
