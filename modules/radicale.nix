{ config, ... }:

{
  sops.secrets.radicale_htpasswd = {
    owner = "radicale";
    group = "radicale";
  };

  services.radicale = {
    enable = true;
    settings = {
      server.hosts = [ "0.0.0.0:5232" ];
      auth = {
        type = "htpasswd";
        htpasswd_filename = config.sops.secrets.radicale_htpasswd.path;
        htpasswd_encryption = "bcrypt";
      };
    };
  };

  networking.firewall.allowedTCPPorts = [ 5232 ];
}
