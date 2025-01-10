{ config, pkgs, ... }:

{
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
                href = "https://${config.networking.hostName}.foxhound-insen.ts.net:8080";
                icon = "scrutiny.svg";
                widget = {
                  type = "scrutiny";
                  url = "http://localhost:8080";
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
}
