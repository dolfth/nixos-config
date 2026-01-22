{ config, pkgs, ... }:

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
        - name: Plex
          group: Media
          url: http://localhost:32400/web
          interval: 60s
          conditions:
            - "[STATUS] < 400"
          alerts:
            - type: ntfy

        - name: Sonarr
          group: Media
          url: http://localhost:8989
          interval: 60s
          conditions:
            - "[STATUS] == 200"
          alerts:
            - type: ntfy

        - name: Radarr
          group: Media
          url: http://localhost:7878
          interval: 60s
          conditions:
            - "[STATUS] == 200"
          alerts:
            - type: ntfy

        - name: Lidarr
          group: Media
          url: http://localhost:8686
          interval: 60s
          conditions:
            - "[STATUS] == 200"
          alerts:
            - type: ntfy

        - name: Bazarr
          group: Media
          url: http://localhost:6767
          interval: 60s
          conditions:
            - "[STATUS] == 200"
          alerts:
            - type: ntfy

        - name: Prowlarr
          group: Media
          url: http://localhost:9696
          interval: 60s
          conditions:
            - "[STATUS] == 200"
          alerts:
            - type: ntfy

        - name: Transmission
          group: Media
          url: http://localhost:9091
          interval: 60s
          conditions:
            - "[STATUS] < 400"
          alerts:
            - type: ntfy

        - name: AdGuard Home
          group: Server
          url: http://localhost:3000
          interval: 60s
          conditions:
            - "[STATUS] == 200"
          alerts:
            - type: ntfy

        - name: Scrutiny
          group: Server
          url: http://localhost:8687
          interval: 60s
          conditions:
            - "[STATUS] == 200"
          alerts:
            - type: ntfy

        - name: Syncthing
          group: Server
          url: http://localhost:8384
          interval: 60s
          conditions:
            - "[STATUS] < 400"
          alerts:
            - type: ntfy
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
