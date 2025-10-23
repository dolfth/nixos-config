{ config, pkgs, ... }:

{
  services.home-assistant = {
    enable = true;
    extraComponents = [
      # Components required to complete the onboarding
      "analytics"
      
      "google_translate"
      "esphome"
      "met"
      "radio_browser"
      "shopping_list"

      "dsmr"
      # Recommended for fast zlib compression
      # https://www.home-assistant.io/integrations/isal
      "isal"
    ];
    config = {
      # Includes dependencies for a basic setup
      # https://www.home-assistant.io/integrations/default_config/
      default_config = {};
    };
  };
  
  # Grant the hass user access to dialout group for serial port access
  users.users.hass.extraGroups = [ "dialout" ];

  # Ensure the serial device is accessible
  services.udev.extraRules = ''
    SUBSYSTEM=="tty", ATTRS{idVendor}=="0403", ATTRS{idProduct}=="6001", SYMLINK+="ttyDSMR", MODE="0666", GROUP="dialout"
  '';
}
