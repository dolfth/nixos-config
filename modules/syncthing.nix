{ config, pkgs, ... }:

let
  user = config.local.primaryUser;
  home = "/home/${user}";
  docs = "${home}/Documents";
  mkFolder = path: devices: { inherit path devices; };
in
{
  services.syncthing = {
    enable = true;
    group = "users";
    user = user;
    guiAddress = "0.0.0.0:8384";
    openDefaultPorts = true;
    dataDir = home;
    configDir = "${home}/.config/syncthing";
    overrideDevices = true;
    overrideFolders = true;
    settings = {
      devices = {
        "gza" = { id = "Z5EGWQK-ZS2DGQC-WJ4BKMS-4EMWVJH-YSX43YL-X44QTRQ-DCWYIBF-BD3NTAT"; };
        "rza" = { id = "TGE6XJM-5F64UQZ-5FWEJLL-3I6MPKB-TFIVDHQ-D5KVOL4-I3FSNLS-YNX7OQK"; };
        "LittleRedRabbit" = { id = "JQ3DHYB-AU3JYGR-BEWLREI-UGMLE6S-6JDS4T3-S5DXKHQ-RSE3RGV-KMUVGAT"; };
      };
      folders = {
        "Documents" = mkFolder docs ["gza"];
        "passwords" = mkFolder "${docs}/passwords" ["rza"];
        "notes" = mkFolder "${docs}/notes" ["rza"];
        "administratie" = mkFolder "${docs}/administratie" ["LittleRedRabbit"];
      };
    };
  };
}
