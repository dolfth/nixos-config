{ config, pkgs, ... }:
{
  # Samba users are independent of system users.
  # https://wiki.samba.org/index.php/Configure_Samba_to_Work_Better_with_Mac_OS_X
  services.samba = {
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
  services.avahi = {
    enable = true;
    publish.enable = true;
    publish.userServices = true;
    openFirewall = true;
  };
}
