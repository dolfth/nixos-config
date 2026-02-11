{ config, ... }:

{
  # Secrets for frame-art-changer (shared into guest via virtiofs)
  sops.secrets.tv_token = {};

  sops.templates."frame-art-changer-env" = {
    content = ''
      TV_TOKEN=${config.sops.placeholder.tv_token}
      NTFY_TOPIC=${config.sops.placeholder.ntfy_topic}
    '';
    path = "/run/frame-art-changer-secrets/env";
  };

  systemd.tmpfiles.rules = [
    "d /run/frame-art-changer-secrets 0700 root root -"
    "d /mnt/media/art 0755 dolf media -"
  ];

  # VLAN 20 subinterface on eno2 for IoT/TV network
  networking.vlans."eno2.20" = {
    id = 20;
    interface = "eno2";
  };

  # MicroVM on VLAN 20 for frame-art-changer
  microvm.vms.artchangervm = {
    autostart = true;

    config = {
      imports = [ ../../modules/frame-art-changer.nix ];

      microvm = {
        hypervisor = "cloud-hypervisor";
        vcpu = 1;
        mem = 256;

        shares = [
          {
            tag = "ro-store";
            source = "/nix/store";
            mountPoint = "/nix/.ro-store";
            proto = "virtiofs";
          }
          {
            tag = "art";
            source = "/mnt/media/art";
            mountPoint = "/art";
            proto = "virtiofs";
          }
          {
            tag = "secrets";
            source = "/run/frame-art-changer-secrets";
            mountPoint = "/run/secrets";
            proto = "virtiofs";
          }
        ];

        writableStoreOverlay = "/nix/.rw-store";

        volumes = [{
          image = "var.img";
          mountPoint = "/var";
          size = 512;
        }];

        interfaces = [{
          type = "macvtap";
          id = "vm-artchanger";
          mac = "02:00:00:00:20:01";
          macvtap = {
            link = "eno2.20";
            mode = "bridge";
          };
        }];
      };

      services.frame-art-changer = {
        enable = true;
        environmentFile = "/run/secrets/env";
      };

      systemd.network = {
        enable = true;
        networks."20-lan" = {
          matchConfig.Type = "ether";
          networkConfig.DHCP = "yes";
        };
      };

      services.openssh.enable = true;

      users.users.root.initialPassword = "microvm";

      system.stateVersion = "24.11";
    };
  };
}
