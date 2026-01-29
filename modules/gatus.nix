{ config, pkgs, lib, ... }:

let
  # Helper to generate endpoint YAML
  mkEndpoint = { name, group, port, path ? "", condition ? "[STATUS] == 200" }: ''
    - name: ${name}
      group: ${group}
      url: http://localhost:${toString port}${path}
      interval: 60s
      conditions:
        - "${condition}"
      alerts:
        - type: ntfy
  '';

  mediaEndpoints = [
    { name = "Plex"; group = "Media"; port = 32400; path = "/web"; condition = "[STATUS] < 400"; }
    { name = "Jellyfin"; group = "Media"; port = 8096; }
    { name = "Sonarr"; group = "Media"; port = 8989; }
    { name = "Radarr"; group = "Media"; port = 7878; }
    { name = "Lidarr"; group = "Media"; port = 8686; }
    { name = "Bazarr"; group = "Media"; port = 6767; }
    { name = "Prowlarr"; group = "Media"; port = 9696; }
    { name = "Transmission"; group = "Media"; port = 9091; condition = "[STATUS] < 400"; }
  ];

  serverEndpoints = [
    { name = "Scrutiny"; group = "Server"; port = 8687; }
    { name = "Syncthing"; group = "Server"; port = 8384; condition = "[STATUS] < 400"; }
  ];

  allEndpoints = lib.concatMapStrings mkEndpoint (mediaEndpoints ++ serverEndpoints);
in
{
  sops.templates."gatus.yaml" = {
    content = ''
      web:
        port: 8080

      alerting:
        ntfy:
          topic: ${config.sops.placeholder.ntfy_topic}
          url: https://ntfy.sh
          priority: 4
          default-alert:
            enabled: true
            failure-threshold: 3
            success-threshold: 2
            send-on-resolved: true

      endpoints:
      ${allEndpoints}
    '';
    owner = "gatus";
    group = "gatus";
    mode = "0400";
  };

  users.users.gatus = {
    isSystemUser = true;
    group = "gatus";
  };
  users.groups.gatus = { };

  systemd.services.gatus = {
    description = "Gatus - Automated developer-oriented status page";
    wantedBy = [ "multi-user.target" ];
    after = [ "network.target" ];
    serviceConfig = {
      Type = "simple";
      User = "gatus";
      Group = "gatus";
      ExecStart = "${pkgs.gatus}/bin/gatus";
      Restart = "on-failure";
      RestartSec = "5s";
      Environment = "GATUS_CONFIG_PATH=${config.sops.templates."gatus.yaml".path}";
    };
    restartTriggers = [ config.sops.templates."gatus.yaml".file ];
  };

  networking.firewall.allowedTCPPorts = [ 8080 ];
}
