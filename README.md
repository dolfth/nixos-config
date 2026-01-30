# NixOS Configuration

Single-host NixOS configuration for a home NAS server using flakes.

## Quick Start

```bash
# Check configuration for errors
nix flake check
# Apply configuration
sudo nixos-rebuild switch --flake #
# Update dependencies
nix flake update
```

## Structure

- `common/` - Shell, editor, and VPN config shared across hosts
- `modules/` - NAS services (media, file sharing, monitoring, sync)
- `hosts/nwa/` - Machine-specific config (boot, hardware, networking)
- `scripts/` - External scripts for modules
- `secrets/` - Encrypted configuration via sops-nix

## Services

- Media stack (Plex, Jellyfin, Radarr, Sonarr, Transmission)
- File sharing (Samba, Time Machine, Syncthing)
- Monitoring (Gatus status page, disk health checks)
- Samsung Frame TV art rotation
- Incus container orchestration
- ZFS storage with snapshots

## Requirements

- NixOS
- Secrets
- Git

## Documentation

See `AGENTS.md` for detailed development guidelines.
