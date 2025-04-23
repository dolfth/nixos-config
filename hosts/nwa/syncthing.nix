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
      };
      folders = {
        "Documents" = {
	  path = "/home/dolf/Documents";
	  devices = ["gza"];
        }; 
      };
    };
  };
}
