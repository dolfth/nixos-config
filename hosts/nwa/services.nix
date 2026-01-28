{ ... }:

{
  services.adguardhome.enable = true;

  services.mealie.enable = true;

  services.scrutiny = {
    enable = true;
    settings.web.listen.port = 8687;
  };
}
