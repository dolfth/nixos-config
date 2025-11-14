{ config, pkgs, ... }:

{
  services.home-assistant = {
    enable = true;
  
    extraComponents = [
      # Components required to complete the onboarding
      "analytics"
      "radio_browser"

      "google_translate"
      "esphome"
      "met"
      "shopping_list"

      "unifi"
      "apple_tv"
      "zha"
      "homewizard"
      # Recommended for fast zlib compression
      # https://www.home-assistant.io/integrations/isal
      "isal"
    ];
    config = {
      
      # Explicitly disable shopping list
      todo = null;

      # https://www.home-assistant.io/integrations/default_config/

      group = {
        zitkamer_lampen = {
          name = "Lampen zitkamer";
          entities = [
            "switch.leeslamp_stekker"
            "switch.booglamp_stekker"
            "switch.lotek_links_van_tv_stekker"
          ];
        };
      };

    automation = [
        {
          alias = "Turn on light on motion";
          trigger = {
            platform = "state";
            entity_id = "binary_sensor.bewegingsmelder";
            to = "on";
          };
          action = {
            service = "light.turn_on";
            target.entity_id = "light.ikea_of_sweden_tradfri_bulb_e27_ww_g95_cl_470lm";
            data = {
              brightness_pct = 100;  # Full brightness on motion
            };
          };
          mode = "restart";  # Restart timer if motion detected again
        }

        # Turn off hallway light after no motion for 5 minutes
        {
          alias = "Turn off light when no motion";
          trigger = {
            platform = "state";
            entity_id = "binary_sensor.bewegingsmelder";
            to = "off";
            for.minutes = 5;
          };
          condition = {
            condition = "sun";
            after = "sunrise";
            before = "sunset";
          };
          action = {
            service = "light.turn_off";
            target.entity_id = "light.ikea_of_sweden_tradfri_bulb_e27_ww_g95_cl_470lm";
          };
        }

        # Turn on hallway light at sunset at 33% brightness
        {
          alias = "Turn on light at sunset";
          trigger = {
            platform = "sun";
            event = "sunset";
          };
          action = {
            service = "light.turn_on";
            target.entity_id = "light.ikea_of_sweden_tradfri_bulb_e27_ww_g95_cl_470lm";
            data = {
              brightness_pct = 33;
            };
          };
        }

        # Return to 33% brightness after motion stops (only at night)
        {
          alias = "Dim light to 33% after motion at night";
          trigger = {
            platform = "state";
            entity_id = "binary_sensor.bewegingsmelder";
            to = "off";
            for.minutes = 2;
          };
          condition = {
            condition = "sun";
            after = "sunset";
            before = "sunrise";
          };
          action = {
            service = "light.turn_on";
            target.entity_id = "light.ikea_of_sweden_tradfri_bulb_e27_ww_g95_cl_470lm";
            data = {
              brightness_pct = 33;
            };
          };
        }

        # Turn off hallwaylight at sunrise
        {
          alias = "Turn off light at sunrise";
          trigger = {
            platform = "sun";
            event = "sunrise";
          };
          action = {
            service = "light.turn_off";
            target.entity_id = "light.ikea_of_sweden_tradfri_bulb_e27_ww_g95_cl_470lm";
          };
        }

        {
          alias = "Turn on evening lights at sunset";
          trigger = {
            platform = "sun";
            event = "sunset";
          };
          action = {
            service = "switch.turn_on";
            target.entity_id = [
              "switch.leeslamp_stekker"
              "switch.booglamp_stekker"
              "switch.lotek_links_van_tv_stekker"
            ];
          };
        }
        ];
      default_config = {};
    };
  };

  # Grant the hass user access to dialout group for serial port access
  users.users.hass.extraGroups = [ "dialout" ];

  # Ensure the serial device is accessible
  services.udev.extraRules = ''
    # Sonoff ZBDongle-E
    SUBSYSTEM=="tty", ATTRS{idVendor}=="1a86", ATTRS{idProduct}=="55d4", SYMLINK+="zigbee", MODE="0666", GROUP="dialout"
      '';
}
