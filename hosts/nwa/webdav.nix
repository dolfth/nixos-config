{ config, pkgs, ... }:

{
  sops.secrets.webdav = { };

  services.webdav = {
    enable = true;
    environmentFile = config.sops.secrets.webdav.path;
    settings = {
      address = "0.0.0.0";
      port = 8080;
      scope = "/home/dolf/Documents/passwords";
      modify = true;
      auth = true;
      users = [
        {
          username = "{env}USERNAME";
          password = "{env}PASSWORD";
        }
      ];
    };
  };
}
