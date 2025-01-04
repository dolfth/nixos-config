{ config, lib, pkgs, ... }:

{
  imports = [
      ./hardware-configuration.nix
    ];

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

  # ZFS
  # Enable zram swap as OpenZFS does not support swap on zvols nor swapfiles on a ZFS dataset.
  zramSwap.enable = true;
  services.zfs.autoScrub.enable = true;


  # Timezone and locale
  time.timeZone = "Europe/Amsterdam";
  console.keyMap = "us";
  i18n = {
    supportedLocales = [ "en_US.UTF-8/UTF-8" "nl_NL.UTF-8/UTF-8" ];
  };

  # Networking
  networking = {
    hostName = "nwa";
    hostId = "04ef5600";
    #useDHCP = false;
    #bridges."bridge0".interfaces = [ "eno2" ];
    #interfaces."bridge0".useDHCP = true;
    firewall.enable = false;
    nftables.enable = true;
  };


  # User accounts
  users.users."dolf"= {
    isNormalUser = true;
    description = "Dolf ter Hofste";
    extraGroups = [ "wheel" "docker" ];
    packages = with pkgs; [];
  };

  # Enable automatic login for the user.
  services.getty.autologinUser = "dolf";


  # Packages
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


  # Graphics
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


  # Services
  services.jellyfin.enable = true;
  services.mealie.enable = true;
  services.scrutiny.enable = true;

  # Syncthing
  services = {
    syncthing = {
        enable = true;
        group = "users";
        user = "dolf";
	guiAddress = "0.0.0.0:8384";
        dataDir = "/home/dolf/";
        configDir = "/home/dolf/.config/syncthing";
    };
  };

  # Tailscale
  services.tailscale.enable = true;
  services.tailscale.useRoutingFeatures = "server";

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

  #Homepage
  services.homepage-dashboard.enable = true;
  services.homepage-dashboard.widgets = [
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
    {
      widget = {
        type = "scrutiny";
        url = "http://nwa:8080";
      };
    }
  ];


  virtualisation.docker.rootless = {
    enable = true;
    setSocketVariable = true;
  };
  
  # Programs
  # Neovim
  programs.neovim = {
    enable = true;
    defaultEditor = true;
   # plugins = [ pkgs.vimPlugins.nvim-treesitter.withAllGrammars ];
  };

  # Fish shell
  programs.fish.enable = true;

  # Launch fish from bash (prevents warning https://fishshell.com/docs/current/index.html#default-shell)
  programs.fish.shellAliases = {
    rr = "sudo nixos-rebuild switch";
    ll = "ls -alh";
  };
  programs.bash = {
    interactiveShellInit = ''
      if [[ $(${pkgs.procps}/bin/ps --no-header --pid=$PPID --format=comm) != "fish" && -z ''${BASH_EXECUTION_STRING} ]]
      then
        shopt -q login_shell && LOGIN_OPTION='--login' || LOGIN_OPTION=""
        exec ${pkgs.fish}/bin/fish $LOGIN_OPTION
      fi
    '';
  };

  
  # SMB shares
  fileSystems."/mnt/smb/media" = {
    device = "//nas/data/media";
    fsType = "cifs";
    options = let
      # this line prevents hanging on network split
      automount_opts = "x-systemd.automount,noauto,x-systemd.idle-timeout=60,x-systemd.device-timeout=5s,x-systemd.mount-timeout=5s,user,users";

      in ["${automount_opts},credentials=/etc/nixos/smb-secrets,uid=1000,gid=100"];
  };

  fileSystems."/mnt/smb/docker" = {
    device = "//nas/docker";
    fsType = "cifs";
    options = let
      automount_opts = "x-systemd.automount,noauto,x-systemd.idle-timeout=60,x-systemd.device-timeout=5s,x-systemd.mount-timeout=5s,user,users";

      in ["${automount_opts},credentials=/etc/nixos/smb-secrets,uid=1000,gid=100"];
  };

  fileSystems."/mnt/docker" = {
    device = "nas:/volume1/docker";
    fsType = "nfs";
  };

  fileSystems."/mnt/media" = {
    device = "nas:/volume1/data";
    fsType = "nfs";
  };

  # Can't touch this
  system.stateVersion = "24.11";
}

