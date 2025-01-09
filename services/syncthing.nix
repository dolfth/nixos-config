{ config, pkgs, ... }:
{
  services.syncthing = {
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
}
