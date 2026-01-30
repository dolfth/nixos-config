# CLAUDE.md

Guidance for AI agents working on this NixOS configuration repository.

## Project Overview

Single-host NixOS configuration using flakes for a home NAS server (hostname: `nwa`). The system runs ZFS storage, media services, file sharing, and various home server applications. Structured to support multiple hosts.

**Flake Inputs:** nixpkgs (unstable), nixarr (media stack), nixvim (editor), sops-nix (secrets)

## Directory Structure

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
├── scripts/               # External scripts referenced by modules
│   └── frame-art-changer/
│       ├── upload-art.py
│       ├── run-upload.sh
│       └── get-token.py
├── hosts/
│   ├── common.nix         # Shared host config (users, packages, locale, sops)
│   └── nwa/               # Physical NAS host
│       ├── configuration.nix
│       ├── hardware-configuration.nix
│       ├── incus.nix
│       ├── power.nix
│       └── zfs.nix
└── secrets/
    └── secrets.yaml       # Encrypted with sops/age
```

**Module Categories:**
- `common/` — Shell, editor, VPN (inherited by all hosts)
- `hosts/common.nix` — Users, packages, locale, sops (inherited by all hosts)
- `modules/` — NAS services (can be selectively imported per host)
- `hosts/<name>/` — Hardware-specific config (boot, disks, networking)
- `scripts/` — External scripts for modules (keeps .nix files clean)

## Mandatory Actions on Every Change

### 1. Always Run Flake Check
```bash
nix flake check
```
This catches syntax errors without requiring sudo. **Do this before asking the user to rebuild.**

### 2. Stage New Files in Git
Nix flakes only see git-tracked files. New files must be staged:
```bash
git add <new-file>
```

### 3. Use Conventional Commits
Format: `type: description`
- `feat:` — New feature or service
- `fix:` — Bug fix
- `chore:` — Maintenance, updates
- `refactor:` — Code restructuring

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

## Code Style & Patterns

### Helper Functions
Use helper functions to reduce repetition:
```nix
# Example from gatus.nix
mkEndpoint = { name, group, port, path ? "", condition ? "[STATUS] == 200" }: ''...'';

# Example from samba.nix
mkShare = user: path: extra: { ... };
```

### Module Organization
- Hardware-specific config stays in `hosts/<name>/`
- Services go in `modules/`
- Large inline scripts should be extracted to `scripts/` and read with `builtins.readFile`

### Secrets Management
Uses sops-nix with age encryption. Key at `/home/dolf/.config/sops/age/keys.txt`.

```nix
# Declare a secret
sops.secrets.my_secret = {};

# Use in a template
sops.templates."config.yaml" = {
  content = ''
    token: ${config.sops.placeholder.my_secret}
  '';
};
```

### Systemd Services Pattern
Consistent structure across modules:
1. Declare system user + group
2. Create tmpfiles rules for directories
3. Define service with proper dependencies (`after`, `wants`)
4. Define timer if periodic execution needed

## Key Infrastructure Details

- **Storage:** ZFS primary with dual boot mirrors (`/boot1`, `/boot2`)
- **Networking:** Bridge `br0` on `eno2` with nftables
- **Containers:** Incus with `vlan20` profile for IoT network access
- **Monitoring:** Gatus status page with ntfy.sh alerts

## Adding a New Host

1. Create `hosts/<name>/` directory
2. Add `hardware-configuration.nix` (generate with `nixos-generate-config`)
3. Add `configuration.nix` with host-specific boot/hardware/networking
4. Add `default.nix` importing common configs and desired modules
5. Add host to `flake.nix` under `nixosConfigurations`

## Adding a New Service Module

1. Create `modules/<service>.nix`
2. Import it in `modules/default.nix`
3. Follow the systemd service pattern (user, tmpfiles, service, timer)
4. Extract large scripts to `scripts/<service>/`
5. Use helper functions for repetitive config

## Workflow Checklist

Before considering a change complete:
- [ ] `nix flake check` passes
- [ ] New files are git-staged
- [ ] Scripts are extracted to `scripts/` if >20 lines
- [ ] Secrets use sops, not hardcoded values (where practical)
- [ ] Service has proper systemd dependencies

## Agent-Specific Notes

### Working with Incus Containers
The `frame-art-changer` runs in an Incus container on vlan20. Key points:
- Container uses ad-hoc `nix shell` for dependencies (no sandbox: `--option sandbox false`)
- Scripts are deployed via heredoc in the container setup
- To update container scripts: delete container, rebuild, restart service

### Samsung Frame TV Token
The TV token changes every time "Allow" is clicked. To get a new token:
```bash
sudo incus exec frame-art-changer -- nix --extra-experimental-features "nix-command flakes" shell --impure --option sandbox false --expr '(builtins.getFlake "nixpkgs").legacyPackages.x86_64-linux.python312.withPackages (ps: with ps; [ websocket-client requests websockets aiohttp async-timeout ])' -c python3 /opt/frame-art-changer/get-token.py
```
Then update `scripts/frame-art-changer/upload-art.py` with the new token.

### Debugging Services
```bash
# Check service status
sudo systemctl status <service>

# View logs
sudo journalctl -u <service> -f

# List pending systemd jobs (if rebuild hangs)
sudo systemctl list-jobs
```

### Common Issues
- **Rebuild hangs:** Check `systemctl list-jobs` for stuck services
- **Flake doesn't see new file:** Run `git add <file>`
- **"Unit already loaded" error:** Run `sudo systemctl reset-failed <unit>`
