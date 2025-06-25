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
        "rza" = { id = "TGE6XJM-5F64UQZ-5FWEJLL-3I6MPKB-TFIVDHQ-D5KVOL4-I3FSNLS-YNX7OQK"; };
        "LittleRedRabbit" = { id = "JQ3DHYB-AU3JYGR-BEWLREI-UGMLE6S-6JDS4T3-S5DXKHQ-RSE3RGV-KMUVGAT"; };
      };
      folders = {
        "Documents" = {
	  path = "/home/dolf/Documents";
	  devices = ["gza"];
        };
        "passwords" = {
          path = "/home/dolf/Documents/passwords";
	  devices = ["rza"];
	};
	"notes" = {
          path = "/home/dolf/Documents/notes";
	  devices = ["rza"];
	};
        "administratie" = {
	  path = "/home/dolf/Documents/administratie";
          devices = ["LittleRedRabbit"];
        };
#	"notes" = {
#	  path = "/home/dolf/Documents/notes";
#          devices = ["rza"];
#	};
      };
    };
  };
}
