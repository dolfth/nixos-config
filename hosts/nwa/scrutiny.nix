{ config, pkgs, ... }:

{
  services.scrutiny = {
    enable = true;
    settings.web.listen.port = 8686;
  };
}
