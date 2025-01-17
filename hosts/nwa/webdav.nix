{ config, pkgs, ... }:

{
   sops.secrets.webdav = {
      sopsFile = ./secrets/webdav.env;
      format = "binary";
  };

  services.webdav = {
    enable = true;
    user = "syncthing";
    environmentFile = config.sops.secrets.webdav.path;
    settings = {
      address = "0.0.0.0";
      port = 8080;
      scope = "/var/lib/syncthing/keepass";
      modify = true;
      auth = true;
      users = [
        {
          username = "{env}USER";
          password = "{env}PASSWORD";
        }
      ];
    };
  };
}
