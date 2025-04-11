{ config, pkgs, ... }:

{
  services.scrutiny = {
    enable = true;
    settings = {
      web.listen.port = 8687;
      notify.urls = [
        "ntfy://ntfy.sh/c22c0a8c-981d-471f-9cae-f36e4c89f19d"
      ];
    };
  };
}
