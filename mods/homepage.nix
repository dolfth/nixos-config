{ config, pkgs, ... }:

{config = {

    sops = {
      secrets."adguard/username" ={};
      secrets."adguard/password" ={};
    };
    services.homepage-dashboard = {
      enable = true;
      settings = {
        title = "nwa";
        background = {
          image = "https://vsthemes.org/uploads/posts/2022-04/1650638025_22-04-2022-19_32_45.webp";
          opacity = 75;
          brightness = 50;
        };
        theme = "dark";
        color = "stone";
        headerStyle = "clean";
        target = "_blank";
        layout."Main" = {
          style = "row";
          columns = 4;
        };
      };
      services = [
        {
          Server = [
            {
              scrutiny = {
                description = "Drive health";
                icon = "scrutiny.svg";
                sitemonitor = "https://${config.networking.hostName}.foxhound-insen.ts.net:8080";
                widget = {
                  type = "scrutiny";
                  url = "http://localhost:8080";
                };
              };
            }
            {
              AdguardHome = {
                description = "DNS filtering";
                icon = "adguard-home.svg";
                sitemonitor = "https://${config.networking.hostName}.foxhound-insen.ts.net:3000";
                widget = {
                  type = "adguard";
                  url = "http://localhost:3000";
                  #username = config.sops.placeholder."adguard/username".path;
                  #password = config.sops.placeholder."adguard/password".path;
                };
              };
            }
          ];
        }
        {
          Media = [
            {
              Plex = {
                description = "Media Server";
                href = "https://${config.networking.hostName}.foxhound-insen.ts.net:32400";
                icon = "plex.svg";
                widget = {
                  key = "{{HOMEPAGE_VAR_PLEX}}";
                  type = "plex";
                  url = "http://localhost:32400";
                };
              };
            }
          ];
        }
      ];
      widgets = [
        {
          resources = {
            label = "System";
            cpu = true;
            disk = "/";
            memory = true;
            uptime = true;
          };
        }
      ];
    };
};
}
