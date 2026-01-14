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
      "server string" = "nwa";
      "min protocol" = "SMB2";
    };

    settings.backup = {
      "path" = "/backup/dolf";
      "valid users" = "dolf";
      "force user" = "dolf";
      "public" = "no";
      "writeable" = "yes";
      "fruit:aapl" = "yes";
      "fruit:time machine" = "yes";
      "vfs objects" = "catia fruit streams_xattr";
    };

    settings.backup-e = {
      "path" = "/backup/emilie";
      "valid users" = "emilie";
      "force user" = "emilie";
      "public" = "no";
      "writeable" = "yes";
      "fruit:aapl" = "yes";
      "fruit:time machine" = "yes";
      "vfs objects" = "catia fruit streams_xattr";
    };

    settings.media = {
      "path" = "/mnt/media";
      "valid users" = "dolf";
      "force user" = "dolf";
      "force group" = "media";
      "public" = "no";
      "writeable" = "yes";
      "fruit:aapl" = "yes";
    };
};

  # Network discovery via zeroconf (Bonjour) networking
  services.avahi = {
    enable = true;
    nssmdns4 = true;
    publish = {
      enable = true;
      userServices = true;
      addresses = true;
      domain = true;
      hinfo = true;
      workstation = true;
    };
    extraServiceFiles = {
      smb = ''
        <?xml version="1.0" standalone='no'?>
        <!DOCTYPE service-group SYSTEM "avahi-service.dtd">
        <service-group>
          <name replace-wildcards="yes">%h</name>
          <service>
            <type>_smb._tcp</type>
            <port>445</port>
          </service>
          <service>
            <type>_device-info._tcp</type>
            <port>9</port>
            <txt-record>model=MacPro</txt-record>
          </service>
          <service>
            <type>_adisk._tcp</type>
            <port>9</port>
            <txt-record>dk0=adVN=backup,adVF=0x82</txt-record>
            <txt-record>dk1=adVN=backup-e,adVF=0x82</txt-record>
            <txt-record>sys=adVF=0x100</txt-record>
          </service>
        </service-group>
      '';
    };
    openFirewall = true;
  };
}
