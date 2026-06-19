{ pkgs, config, inputs, ... }:

let
  user = config.local.primaryUser;
  # General agent workspace, read-write. Host folder lives under the user's
  # Documents; the guest sees it at a clean /home/dolf/hermes-workspace path.
  # Grant/revoke projects by moving them in/out of the host folder — no rebuild
  # needed to change contents, only to add/remove a share entry like this one.
  workspaceSrc = "/home/${user}/Documents/_hermes";
  workspaceMnt = "/home/${user}/hermes-workspace";
  # Must sit on an all-root-owned ancestry: systemd-tmpfiles refuses to create a
  # root-owned dir beneath a non-root-owned path (unsafe path transition,
  # CVE-2017-18078). /home/dolf (dolf) and /var/lib/microvms (microvm) both trip
  # it; /var/lib is root-owned, so put it directly there.
  persistDir = "/var/lib/hermesvm";
in
{
  # Attach the TAP interface to the existing br0 bridge
  systemd.network.networks."21-vm-hermes" = {
    matchConfig.Name = "vm-hermes";
    networkConfig.Bridge = "br0";
  };

  # Pre-create persistent directories on the host.
  # Only Tailscale state is host-side (so the node identity survives var.img
  # recreation and is easy to inspect/back up). Hermes state lives inside the
  # persistent var.img volume, managed by the guest.
  systemd.tmpfiles.rules = [
    "d ${persistDir}/tailscale 0700 root root -"
  ];

  # Discord bot token for the Hermes gateway. Setting DISCORD_BOT_TOKEN in the
  # agent's environment is all it takes to enable the Discord platform
  # (gateway/config.py auto-enables it on token presence). The token lives in
  # secrets/secrets.yaml (sops); we render it into an env file on the host and
  # share it read-only into the guest below — same mechanism as artchangervm.
  sops.secrets.discord_bot_token = { };
  sops.templates."hermes-env".content = ''
    DISCORD_BOT_TOKEN=${config.sops.placeholder.discord_bot_token}
  '';

  microvm.vms.hermesvm = {
    autostart = true;

    config = {
      imports = [
        ../../common
        inputs.hermes-agent.nixosModules.default
      ];

      microvm = {
        hypervisor = "cloud-hypervisor";
        vcpu = 4;
        mem = 4096;
        vsock.cid = 43;   # unique per-VM (artchangervm uses 42); enables systemd-notify readiness

        shares = [
          {
            tag = "ro-store";
            source = "/nix/store";
            mountPoint = "/nix/.ro-store";
            proto = "virtiofs";
          }
          {
            tag = "tailscale";
            source = "${persistDir}/tailscale";
            mountPoint = "/var/lib/tailscale";
            proto = "virtiofs";
          }
          {
            # Agent workspace, read-write. Host dir is owned dolf:users (uid
            # 1000), and the guest's dolf is uid 1000, so it owns the tree —
            # read/write works with no group plumbing. The host folder must
            # exist before the VM boots (virtiofs source).
            tag = "workspace";
            source = workspaceSrc;
            mountPoint = workspaceMnt;
            proto = "virtiofs";
          }
	  {
           tag = "music";
           source = "${config.local.mediaDir}/music";
           mountPoint = "${config.local.mediaDir}/music";
           proto = "virtiofs";
	   readOnly = true;
           }
          {
            # Rendered sops secrets (host) → guest /run/secrets, read-only. The
            # gateway reads DISCORD_BOT_TOKEN from /run/secrets/hermes-env via
            # services.hermes-agent.environmentFiles below.
            tag = "secrets";
            source = "/run/secrets/rendered";
            mountPoint = "/run/secrets";
            proto = "virtiofs";
            readOnly = true;
          }
        ];

        writableStoreOverlay = "/nix/.rw-store";

        # Holds /var/lib/hermes (sessions, memories, state.db) 
        volumes = [{
          image = "var.img";
          mountPoint = "/var";
          size = 8192;
        }];

        interfaces = [{
          type = "tap";
          id = "vm-hermes";
          mac = "02:00:00:00:00:03";
        }];
      };

      # Nix store shutdown deadlock workaround:
      # Without this, systemd tries to unmount /nix/store during shutdown,
      # but umount lives in /nix/store, causing a deadlock.
      systemd.mounts = [
        {
          what = "store";
          where = "/nix/store";
          overrideStrategy = "asDropin";
          unitConfig.DefaultDependencies = false;
        }
      ];

      # Stable identity for reliable SSH: a fixed hostname keeps the MagicDNS
      # name `hermes` constant, and persisted Tailscale state (above) keeps the
      # node + SSH host keys stable across rebuilds. Connect with
      # `tailscale ssh hermes` to bypass known_hosts entirely.
      networking.hostName = "hermes";

      # Guest networking — DHCP on the main LAN via br0
      systemd.network = {
        enable = true;
        networks."20-lan" = {
          matchConfig.Type = "ether";
          networkConfig.DHCP = "yes";
        };
      };

      services.tailscale = {
        enable = true;
        extraUpFlags = [ "--ssh" ];
        # Headless bootstrap: tailscaled auto-runs `tailscale up --auth-key=... --ssh`
        # on boot. The key file lives in the persisted /var/lib/tailscale share
        # (host: /var/lib/hermesvm/tailscale/authkey) — created at runtime, never
        # in git. Once the node is up, persisted state keeps it authed; this line
        # and the file can then be removed.
        authKeyFile = "/var/lib/tailscale/authkey";
      };

      users.users.${user} = {
        isNormalUser = true;
        uid = 1000;
        # `hermes` group → access to the gateway's shared state dir (2770) so the
        # interactive `hermes` CLI uses the same config/sessions as the service.
        # The module only auto-adds users to this group in container mode.
        extraGroups = [ "wheel" "hermes" ];
      };

      # Hermes agent — always-on gateway + CLI on PATH.
      # Model points at the local OpenAI-compatible endpoint on the LAN.
      services.hermes-agent = {
        enable = true;
        addToSystemPackages = true;   # `hermes` CLI available for interactive use
        container.enable = false;     # native hardened systemd service (no docker/podman in-VM)
        settings = {
          model = {
            provider = "custom";                   # custom OpenAI-compatible endpoint
            default = "Qwen3.6-35B-A3B-4bit";       # main model id — MUST be `default` (not `model`); the gateway reads model.default
            base_url = "http://gza:8000/v1";        # local LLM endpoint (must be resolvable from the VM)
            api_key = "1234";                       # read because provider == "custom"
          };
          # Short names for the `/model` switcher (and tab-completion). Both
          # models are served by the same gza endpoint, so they reuse the
          # custom provider + model.api_key above (DirectAlias carries no key).
          # `a3b` is the default 35B MoE; `optiq` is the 27B OptiQ build.
          model_aliases = {
            a3b = {
              model = "Qwen3.6-35B-A3B-4bit";
              provider = "custom";
              base_url = "http://gza:8000/v1";
            };
            optiq = {
              model = "Qwen3.6-27B-OptiQ-4bit";
              provider = "custom";
              base_url = "http://gza:8000/v1";
            };
          };
          toolsets = [ "all" ];
          terminal = { backend = "local"; cwd = "."; };
        };

        # Tools the agent reaches for from its shell. extraPackages (not plain
        # systemPackages) is the right knob: it lands on the gateway service
        # PATH that the local terminal tool inherits, and on the interactive
        # `hermes` CLI's per-user profile. The package already provides git,
        # node, ripgrep, ssh and ffmpeg; 
        extraPackages = with pkgs; [
          curl
          python3
          chromium   # headless engine for the `browser` toolset (agent-browser)
	  exiftool
        ];

        # Discord support lives in the `messaging` optional-dependency group
        # (discord.py + aiohttp + brotlicffi). Pulling the group in resolves it
        # into the sealed venv alongside core deps — no PYTHONPATH patching. The
        # Discord gateway still needs a DISCORD_BOT_TOKEN at runtime; that's a
        # secret, so it goes in environmentFiles, not the plaintext .env below.
        extraDependencyGroups = [ "messaging" ];

        # Non-secret env, merged into the agent's .env. agent-browser (the
        # `browser` toolset's backend, fetched at runtime via `npx`) normally
        # downloads its own Chromium through Playwright, but that build is
        # dynamically linked and won't run on NixOS. AGENT_BROWSER_EXECUTABLE_PATH
        # is the documented way to point it at a pre-installed browser, so aim it
        # at the nixpkgs chromium added to extraPackages above.
        environment = {
          AGENT_BROWSER_EXECUTABLE_PATH = "${pkgs.chromium}/bin/chromium";
        };

        # Secrets (DISCORD_BOT_TOKEN) from the sops-rendered env file shared in
        # via virtiofs above. Kept out of `environment` (plaintext .env).
        environmentFiles = [ "/run/secrets/hermes-env" ];
      };

      environment.systemPackages = with pkgs; [
        git
        jq
        ripgrep
        fd
        htop
      ];

      system.stateVersion = "24.11";
    };
  };
}
