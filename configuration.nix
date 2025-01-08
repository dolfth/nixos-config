{ config, lib, pkgs, ... }:

{
  # imports = [ ./hardware-configuration.nix ];

  nix.settings.experimental-features = [ "nix-command" "flakes" ];

##### Boot Settings ############################################################

  # Use the systemd-boot EFI boot loader.
  # boot.loader.systemd-boot.enable = true;
  # boot.loader.efi.canTouchEfiVariables = true;

  boot.loader.grub = {
    enable = true;
    zfsSupport = true;
    efiSupport = true;
    efiInstallAsRemovable = true;
    mirroredBoots = [
      { devices = ["nodev"]; path ="/boot"; }
    ];
  };

##### File Systems #############################################################

  fileSystems."/mnt/media" = {
    device = "//nas/data/";
    fsType = "cifs";
    options = let
      # this line prevents hanging on network split
      automount_opts = "x-systemd.automount,noauto,x-systemd.idle-timeout=60,x-systemd.device-timeout=5s,x-systemd.mount-timeout=5s,user,users";

      in ["${automount_opts},credentials=./smb-secrets,uid=${toString config.users.users.dolf.uid},gid=${toString config.users.groups.dolf.gid}"];
  };


#  fileSystems."/mnt/docker" = {
#    device = "//nas/docker";
#    fsType = "cifs";
#    options = let
#      # this line prevents hanging on network split
#      automount_opts = "x-systemd.automount,noauto,x-systemd.idle-timeout=60,x-systemd.device-timeout=5s,x-systemd.mount-timeout=5s,user,users";
#
#      in ["${automount_opts},credentials=./smb-secrets,uid=${toString config.users.users.dolf.uid},gid=${toString config.users.groups.dolf.gid}"];
#  };


##### Hardware and Graphics ####################################################

  # Enable zram swap as OpenZFS doesn't support swap on zvols
  # nor on swapfiles on a ZFS dataset.

  zramSwap.enable = true;

    hardware.graphics = {
      enable = true;
      extraPackages = with pkgs; [
        intel-media-driver
        intel-compute-runtime
      ];
    };

##### Timezone & Locale ########################################################

  time.timeZone = "Europe/Amsterdam";
  console.keyMap = "us";
  i18n = {
    supportedLocales = [ "en_US.UTF-8/UTF-8" "nl_NL.UTF-8/UTF-8" ];
  };

##### Networking ###############################################################

  networking = {
    hostName = "nwa";
    hostId = "04ef5600";
    interfaces.en02.ipv4.addresses = [{
      address = "192.168.2.115";
      prefixLength = 24;
    }];
    #useDHCP = false;
    #bridges."bridge0".interfaces = [ "eno2" ];
    #interfaces."bridge0".useDHCP = true;
    firewall.enable = false;
    nftables.enable = true;
  };

##### User Accounts ############################################################

  users.users."dolf"= {
    isNormalUser = true;
    uid = 1000;
    group = "dolf";
    description = "Dolf ter Hofste";
    extraGroups = [ "wheel" "docker" "users" ];
    packages = with pkgs; [];
  };

  users.users."docker"= {
    isNormalUser = true;
    uid = 1003;
    group = "docker";
    extraGroups = [ "users" ];
    packages = with pkgs; [];
    shell = pkgs.fish;
  };

  users.groups.dolf.gid = 1000;
  #users.groups.docker.gid = 1003;

  # Enable automatic login for the user.
  services.getty.autologinUser = "dolf";

##### Packages #################################################################

  nixpkgs.config.allowUnfree = true;
  environment.systemPackages = with pkgs; [
    cifs-utils
    cockpit
    docker-compose
    git
    htop
    jellyfin
    jellyfin-web
    jellyfin-ffmpeg
    jq
    lshw
    parted
    sanoid
    smartmontools
  ];

  ##### Programs #################################################################

  programs = {
    neovim.enable = true;
    neovim.defaultEditor = true;
    starship.enable = true;
    starship.presets = [ "tokyo-night" ];
    fish.enable = true;
    fish.shellAliases = {
      cc = "nvim /etc/nixos/configuration.nix";
      rr = "sudo nixos-rebuild switch --flake";
      ll = "ls -alh";
     };
    bat.enable = true;
  };

##### Services #################################################################

  services = {
    
    #lldap.enable = true;
    scrutiny.enable = true;

    jellyfin.enable = true;
    plex.enable = true;
    radarr.enable = true;

    homepage-dashboard = {
      enable = true;
      settings = {
        title = "nwa";
        background = {
          image = "https://vsthemes.org/uploads/posts/2022-04/1650638025_22-04-2022-19_32_45.webp";
          opacity = 75;
          brightness = 50;
        };
        theme = "dark";
        color = "stone";
        headerStyle = "clean";
        target = "_blank";
        layout."Main" = {
          style = "row";
          columns = 4;
        };
      };
      services = [
        {
          Server = [
            {
              scrutiny = {
                description = "Drive health";
                href = "https://${config.networking.hostName}.foxhound-insen.ts.net:8080";
                icon = "scrutiny.svg";
                widget = {
                  type = "scrutiny";
                  url = "http://localhost:8080";
                };
              };
            }
          ];
        }
        {
          Media = [
            {
              Plex = {
                description = "Media Server";
                href = "https://${config.networking.hostName}.foxhound-insen.ts.net:32400";
                icon = "plex.svg";
                widget = {
                  key = "{{HOMEPAGE_VAR_PLEX}}";
                  type = "plex";
                  url = "http://localhost:32400";
                };
              };
            }
          ];
        }
      ];
      widgets = [
        {
          resources = {
            label = "System";
            cpu = true;
            disk = "/";
            memory = true;
            uptime = true;
          };
        }
      ];
    };

    syncthing = {
      enable = true;
      group = "users";
      user = "dolf";
      guiAddress = "0.0.0.0:8384";
      openDefaultPorts = true;
      dataDir = "/home/dolf/";
      configDir = "/home/dolf/.config/syncthing";
      overrideDevices = true;
      overrideFolders = true;
      settings = {
        devices = {
          "gza" = { id = "Z5EGWQK-ZS2DGQC-WJ4BKMS-4EMWVJH-YSX43YL-X44QTRQ-DCWYIBF-BD3NTAT"; };
          "nas" = { id = "TONHWXI-TTLGRND-MJ54BVE-UW3NLSR-AR24U7N-3PXKIHU-I66I3QX-AQLDBQ7"; };
        };
        folders = {
          "Documents" = {
            path = "/home/dolf/Documents";
            devices = [ "gza" "nas" ];
          };
        };
      };
    };

    tailscale = {
      enable = true;
      extraUpFlags = [ "--ssh" ];
      useRoutingFeatures = "server";
    };
    
    # ZFS snapshots
    sanoid = {
      enable = true;
      interval = "hourly";
      templates = {

        frequent = {
            hourly = 24;
            daily = 7;
            monthly = 12;
            yearly = 2;
            autoprune = true;
            autosnap = true;
          };

        recent = {
          hourly = 24;
          daily = 7;
          autoprune = true;
          autosnap = true;
        };

      };
      datasets = {
        
	"rpool/home" = {
          useTemplate = ["frequent"];
        };

        "rpool/persist" = {
          useTemplate = ["recent"];
	};
      };
    };
    
    # Samba users are independent of system users.
    # https://wiki.samba.org/index.php/Configure_Samba_to_Work_Better_with_Mac_OS_X
    samba = {
      enable = true;
      nsswins = false;
      nmbd.enable = false;
      openFirewall = true;
      settings.global = {

        "server smb encrypt" = "required";
	"server string" = "nwa";
        "fruit:model" = "MacPro";
	"fruit:metadata" = "stream";
        "fruit:veto_appledouble" = "no";
        "fruit:nfs_aces" = "no";
        "fruit:wipe_intentionally_left_blank_rfork" = "yes"; 
        "fruit:delete_empty_adfiles" = "yes";
        "vfs objects" = "catia fruit streams_xattr";
      };

      settings.backup = {
        "path" = "/backup/dolf";
        "valid users" = "dolf";
        "force user" = "dolf";
        #"force group" = "username";
        "public" = "no";
        "writeable" = "yes";
        "fruit:time machine" = "yes";
	"fruit:time machine max size" = "1500G";
      };
    };

    # for zeroconf (Bonjour) networking
    avahi = {
      enable = true;
      publish.enable = true;
      publish.userServices = true;
      openFirewall = true;
    };

    zfs = {
      autoScrub.enable = true;
      trim.enable = true;
      zed.settings = {
        ZED_NOTIFY_INTERVAL_SECS=3600;
        ZED_NTFY_TOPIC = "c22c0a8c-981d-471f-9cae-f36e4c89f19d";
        ZED_NOTIFY_VERBOSE = true;
        ZED_SCRUB_AFTER_RESILVER = true;
      };
    };
  };
##### Containers ###############################################################

  virtualisation.docker = {
    enable = true;
    daemon.settings = {
      userland-proxy = false;
      experimental = true;
      metrics-addr = "0.0.0.0:9323";
      ipv6 = true;
      fixed-cidr-v6 = "fd00::/80";
    };
  };

##### Voodoo ###################################################################

  # create a oneshot job to authenticate to Tailscale
  systemd.services.tailscale-autoconnect = {
    description = "Automatic connection to Tailscale";

    # make sure tailscale is running before trying to connect to tailscale
    after = [ "network-pre.target" "tailscale.service" ];
    wants = [ "network-pre.target" "tailscale.service" ];
    wantedBy = [ "multi-user.target" ];

    # set this service as a oneshot job
    serviceConfig.Type = "oneshot";

    # have the job run this shell script
    script = with pkgs; ''
      # wait for tailscaled to settle
      sleep 2

      # check if we are already authenticated to tailscale
      status="$(${tailscale}/bin/tailscale status -json | ${jq}/bin/jq -r .BackendState)"
      if [ $status = "Running" ]; then # if so, then do nothing
        exit 0
      fi

      # otherwise authenticate with tailscale
      ${tailscale}/bin/tailscale up -authkey tskey-auth-k8rAT51p7111CNTRL-G34YeecHDfJRT5EgrhPafJ1iSog2yLYR
    '';
  };

  # Launch fish from bash (prevents warning https://fishshell.com/docs/current/index.html#default-shell)
  programs.bash = {
    interactiveShellInit = ''
      if [[ $(${pkgs.procps}/bin/ps --no-header --pid=$PPID --format=comm) != "fish" && -z ''${BASH_EXECUTION_STRING} ]]
      then
        shopt -q login_shell && LOGIN_OPTION='--login' || LOGIN_OPTION=""
        exec ${pkgs.fish}/bin/fish $LOGIN_OPTION
      fi
    '';
  };

##### NixOS System Installed Version (Do not edit) #############################

  system.stateVersion = "24.11";

################################################################################
}
