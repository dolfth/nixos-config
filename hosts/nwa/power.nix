{ config, lib, pkgs, ... }:

{
##### Power Management ##########################################################

  powerManagement = {
    enable = true;
    powertop.enable = true;  # Auto-tune power settings on boot
    cpuFreqGovernor = "powersave";  # Use powersave governor for efficiency
  };

  # Intel P-state driver and power-saving kernel parameters
  boot.kernelParams = [
    "intel_pstate=active"           # Use Intel P-state driver
    "pcie_aspm=force"               # Force PCIe Active State Power Management
    "pcie_aspm.policy=powersave"    # Use powersave ASPM policy
  ];

  # Audio power saving (if audio hardware present)
  boot.extraModprobeConfig = ''
    options snd_hda_intel power_save=1
  '';

##### Disk Power Management #####################################################

  # HDD spindown after 20 minutes of inactivity (value 244 = 20 min)
  # USB autosuspend after 2 seconds of inactivity
  # Keep Ethernet NIC always on (runs after PowerTOP so it doesn't get overridden)
  systemd.services.nic-power-on = {
    description = "Disable power management on Ethernet NIC";
    after = [ "powertop.service" "network.target" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.bash}/bin/bash -c 'echo on > /sys/devices/pci0000:00/0000:00:1f.6/power/control'";
      RemainAfterExit = true;
    };
  };

  services.udev.extraRules = ''
    # Spin down idle HDDs after 20 minutes
    ACTION=="add", SUBSYSTEM=="block", KERNEL=="sd[a-z]", RUN+="${pkgs.hdparm}/bin/hdparm -S 244 /dev/%k"

    # USB autosuspend
    ACTION=="add", SUBSYSTEM=="usb", ATTR{power/autosuspend}="2"
  '';

##### Wake-on-LAN (for future use) ##############################################

  # Enable WoL so the system can be woken remotely if suspended
  networking.interfaces.eno2.wakeOnLan.enable = true;

################################################################################
}
