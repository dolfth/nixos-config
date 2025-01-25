{ config, pkgs, ... }:

{
  sops.secrets.webdav = { };

  services.webdav = {
    enable = true;
    user = "dolf";
    environmentFile = config.sops.secrets.webdav.path;
    settings = {
      address = "0.0.0.0";
      port = 8080;
      tls = true;
      cert = "/home/dolf/.config/tailscale/certificate.crt";
      key = "/home/dolf/.config/tailscale/key.key";
      modify = true;
      auth = true;
      users = [
        {
          username = "{env}USERNAME";
          password = "{env}PASSWORD";
          scope = "/home/dolf/Documents/passwords";
        }
      ];
    };
  };
}
