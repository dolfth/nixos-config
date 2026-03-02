{ config, inputs, ... }:

let
  user = config.local.primaryUser;
  mediaDir = config.local.mediaDir;
in
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
    "d ${mediaDir}/art 0755 ${user} media -"
  ];

  # VLAN 20 subinterface on br0 for IoT/TV network
  networking.vlans."br0.20" = {
    id = 20;
    interface = "br0";
  };

  # Bring br0.20 UP (no IP needed, just carrier for macvtap)
  systemd.network.networks."40-br0-20" = {
    matchConfig.Name = "br0.20";
    networkConfig.LinkLocalAddressing = "no";
    linkConfig.RequiredForOnline = "no";
  };

  # Ensure artchangervm waits for the VLAN interface before starting
  systemd.services."microvm@artchangervm" = {
    after = [ "sys-subsystem-net-devices-br0.20.device" ];
    requires = [ "sys-subsystem-net-devices-br0.20.device" ];
  };

  # MicroVM on VLAN 20 for frame-art-changer
  microvm.vms.artchangervm = {
    autostart = true;

    config = {
      imports = [
        ../../common
        ../../modules/frame-art-changer.nix
      ];

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
            source = "${mediaDir}/art";
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
            link = "br0.20";
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

      system.stateVersion = "24.11";
    };
  };
}
