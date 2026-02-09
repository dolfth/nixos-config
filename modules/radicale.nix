{ config, pkgs, ... }:

let
  domain = "nwa.foxhound-insen.ts.net";
  certDir = "/var/lib/tailscale-certs";
in
{
  sops.secrets.radicale_htpasswd = {
    owner = "radicale";
    group = "radicale";
  };

  services.radicale = {
    enable = true;
    settings = {
      server.hosts = [ "127.0.0.1:5232" ];
      auth = {
        type = "htpasswd";
        htpasswd_filename = config.sops.secrets.radicale_htpasswd.path;
        htpasswd_encryption = "bcrypt";
      };
    };
  };

  services.caddy = {
    enable = true;
    virtualHosts."${domain}" = {
      extraConfig = ''
        tls ${certDir}/${domain}.crt ${certDir}/${domain}.key
        reverse_proxy localhost:5232
      '';
    };
  };

  systemd.tmpfiles.rules = [
    "d ${certDir} 0750 root caddy -"
  ];

  systemd.services.tailscale-cert = {
    description = "Fetch/renew Tailscale HTTPS certificate";
    after = [ "tailscaled.service" ];
    wants = [ "tailscaled.service" ];
    before = [ "caddy.service" ];
    requiredBy = [ "caddy.service" ];
    serviceConfig.Type = "oneshot";
    script = ''
      ${pkgs.tailscale}/bin/tailscale cert \
        --cert-file ${certDir}/${domain}.crt \
        --key-file ${certDir}/${domain}.key \
        ${domain}
      chown root:caddy ${certDir}/${domain}.crt ${certDir}/${domain}.key
      chmod 640 ${certDir}/${domain}.crt ${certDir}/${domain}.key
      if ${pkgs.systemd}/bin/systemctl is-active --quiet caddy; then
        ${pkgs.systemd}/bin/systemctl reload caddy
      fi
    '';
  };

  systemd.timers.tailscale-cert = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "weekly";
      Persistent = true;
    };
  };

  networking.firewall.allowedTCPPorts = [ 443 ];
}
