{ config, lib, pkgs, ... }:

{
  imports = [
      ./hardware-configuration.nix
    ];

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

##### ZFS Settings #############################################################

  # Enable zram swap as OpenZFS does not support swap on zvols nor swapfiles on a ZFS dataset.
  zramSwap.enable = true;
  services.zfs.autoScrub.enable = true;

##### File Systems #############################################################

  fileSystems."/mnt/media" = {
    device = "//nas/data/media";
    fsType = "cifs";
    options = let
      # this line prevents hanging on network split
      automount_opts = "x-systemd.automount,noauto,x-systemd.idle-timeout=60,x-systemd.device-timeout=5s,x-systemd.mount-timeout=5s,user,users";

      in ["${automount_opts},credentials=/etc/nixos/smb-secrets,uid=1000,gid=100"];
  };
 
##### Graphics #################################################################

  nixpkgs.config.packageOverrides = pkgs: {
      vaapiIntel = pkgs.vaapiIntel.override { enableHybridCodec = true; };
    };
    hardware.graphics = {
      enable = true;
      extraPackages = with pkgs; [
        intel-media-driver
        intel-vaapi-driver # previously vaapiIntel
        vaapiVdpau
        libvdpau-va-gl
        intel-compute-runtime # OpenCL filter support (hardware tonemapping and subtitle burn-in)
        vpl-gpu-rt # QSV on 11th gen or newer
        intel-media-sdk # QSV up to 11th gen
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
    #useDHCP = false;
    #bridges."bridge0".interfaces = [ "eno2" ];
    #interfaces."bridge0".useDHCP = true;
    firewall.enable = false;
    nftables.enable = true;
  };

##### User Accounts ############################################################

  users.users."dolf"= {
    isNormalUser = true;
    description = "Dolf ter Hofste";
    extraGroups = [ "wheel" "docker" ];
    packages = with pkgs; [];
  };

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
    fish.enable = true;
    fish.shellAliases = {
      cc = "sudo vim /etc/nixos/configuration.nix";
      rr = "sudo nixos-rebuild switch";
      ll = "ls -alh";
     };
  };


##### Services #################################################################

  services = {
    
    jellyfin.enable = true;
    mealie.enable = true;
    scrutiny.enable = true;
    
    homepage-dashboard = {
      enable = true;
      widgets = [
        {
          resources = {
            cpu = true;
            disk = "/";
            memory = true;
          };
        }
        {
          search = {
            provider = "duckduckgo";
            target = "_blank";
          };
        }
      ];
    };
  
    syncthing = {
      enable = true;
      group = "users";
      user = "dolf";
      guiAddress = "0.0.0.0:8384";
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
      useRoutingFeatures = "server";
    };
  };

##### Containers ###############################################################

  virtualisation.docker.rootless = {
    enable = true;
    setSocketVariable = true;
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

