{ config, pkgs, inputs, ... }:

{
  # Add git to recyclarr service PATH (needed for cloning config-templates)
  systemd.services.recyclarr.path = [ pkgs.git ];

  services.plex = {
    enable = true;
    dataDir = "/var/lib/plex";
    };

  nixarr = {
    enable = true;
    mediaDir = "/mnt/media";
    stateDir = "/var/lib/nixarr";
    jellyfin.enable = true;
    transmission.enable = true;
    bazarr.enable = true;
    lidarr.enable = true;
    prowlarr.enable = true;
    radarr.enable = true;
    readarr.enable = false;
    sonarr.enable = true;

    recyclarr = {
      enable = true;
      schedule = "daily";
      configFile = pkgs.writeText "recyclarr.yml" ''
        radarr:
          movies:
            base_url: http://127.0.0.1:7878
            api_key: !env_var RADARR_API_KEY
            delete_old_custom_formats: true
            replace_existing_custom_formats: true
            include:
              - template: radarr-quality-definition-movie
              - template: radarr-quality-profile-remux-web-2160p
              - template: radarr-custom-formats-remux-web-2160p

            custom_formats:
              - trash_ids:
                  - 496f355514737f7d83bf7aa4d24f8169  # TrueHD Atmos
                  - 2f22d89048b01681dde8afe203bf2e95  # DTS:X
                  - 417804f7f2c4308c1f4c5d380d4c4475  # ATMOS (undefined)
                  - 1af239278386be2919e1bcee0bde047e  # DD+ Atmos
                  - 3cafb66171b47f226146a0770576870f  # TrueHD
                  - dcf3ec6938fa32445f590a4da84256cd  # DTS-HD MA
                assign_scores_to:
                  - name: Remux + WEB 2160p
                    score: 5000

        sonarr:
          tv:
            base_url: http://127.0.0.1:8989
            api_key: !env_var SONARR_API_KEY
            delete_old_custom_formats: true
            replace_existing_custom_formats: true
            include:
              - template: sonarr-quality-definition-series
              - template: sonarr-v4-quality-profile-web-1080p
              - template: sonarr-v4-custom-formats-web-1080p
      '';
    };
  };
}
