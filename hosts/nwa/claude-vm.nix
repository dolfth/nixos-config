{ pkgs, ... }:

let
  persistDir = "/home/dolf/microvm/claudevm";
in
{
  # Attach the TAP interface to the existing br0 bridge
  systemd.network.networks."21-vm-claude" = {
    matchConfig.Name = "vm-claude";
    networkConfig.Bridge = "br0";
  };

  # Pre-create persistent directories on the host
  systemd.tmpfiles.rules = [
    "d ${persistDir}/claude-config 0700 dolf dolf -"
    "d ${persistDir}/workspace 0755 dolf dolf -"
    "d ${persistDir}/tailscale 0700 root root -"
  ];

  microvm.vms.claudevm = {
    autostart = true;

    config = {
      microvm = {
        hypervisor = "cloud-hypervisor";
        vcpu = 4;
        mem = 4096;

        shares = [
          {
            tag = "ro-store";
            source = "/nix/store";
            mountPoint = "/nix/.ro-store";
            proto = "virtiofs";
          }
          {
            tag = "claude-config";
            source = "${persistDir}/claude-config";
            mountPoint = "/home/dolf/.claude";
            proto = "virtiofs";
          }
          {
            tag = "workspace";
            source = "${persistDir}/workspace";
            mountPoint = "/home/dolf/workspace";
            proto = "virtiofs";
          }
          {
            tag = "tailscale";
            source = "${persistDir}/tailscale";
            mountPoint = "/var/lib/tailscale";
            proto = "virtiofs";
          }
        ];

        writableStoreOverlay = "/nix/.rw-store";

        volumes = [{
          image = "var.img";
          mountPoint = "/var";
          size = 2048;
        }];

        interfaces = [{
          type = "tap";
          id = "vm-claude";
          mac = "02:00:00:00:00:02";
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

      # Guest networking — DHCP on the main LAN via br0
      systemd.network = {
        enable = true;
        networks."20-lan" = {
          matchConfig.Type = "ether";
          networkConfig.DHCP = "yes";
        };
      };

      services.openssh.enable = true;

      services.tailscale = {
        enable = true;
        extraUpFlags = [ "--ssh" ];
      };

      users.users.dolf = {
        isNormalUser = true;
        uid = 1000;
        initialPassword = "microvm";
        extraGroups = [ "wheel" ];
      };

      environment.systemPackages = with pkgs; [
        claude-code
        git
        jq
        ripgrep
        fd
        htop
      ];

      # Point Claude Code at the persistent config dir (virtiofs share)
      environment.sessionVariables.CLAUDE_CONFIG_DIR = "/home/dolf/.claude";

      system.stateVersion = "24.11";
    };
  };
}
