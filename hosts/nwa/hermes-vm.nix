{ pkgs, config, inputs, ... }:

let
  user = config.local.primaryUser;
  # Single media subfolder shared into the guest read-write.
  sharedDir = "${config.local.mediaDir}/radio/Solid Steel (tagged)";
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
            # "Solid Steel (tagged)" radio folder, read-write. virtiofs passes
            # numeric UIDs/GIDs through untouched: the dir is owned dolf:media
            # (1000:169), so the guest's dolf (uid 1000, in the media group
            # declared below) can read and write it.
            tag = "solidsteel";
            source = sharedDir;
            mountPoint = sharedDir;
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
        ];

        writableStoreOverlay = "/nix/.rw-store";

        # Holds /var/lib/hermes (sessions, memories, state.db) — bumped from the
        # old claudevm's 2 GB.
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

      # Match the host's media group GID so virtiofs UID/GID passthrough lines up
      # and the guest's dolf can write group-owned files in the shared folder.
      users.groups.media.gid = 169;

      users.users.${user} = {
        isNormalUser = true;
        uid = 1000;
        # `hermes` group → access to the gateway's shared state dir (2770) so the
        # interactive `hermes` CLI uses the same config/sessions as the service.
        # The module only auto-adds users to this group in container mode.
        # `media` group → read-write access to the shared media folder.
        extraGroups = [ "wheel" "hermes" "media" ];
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
          toolsets = [ "all" ];
          terminal = { backend = "local"; cwd = "."; };
        };
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
