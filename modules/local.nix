{ lib, ... }:

{
  options.local = {
    primaryUser = lib.mkOption {
      type = lib.types.str;
      default = "dolf";
      description = "Primary admin user account name";
    };

    mediaDir = lib.mkOption {
      type = lib.types.str;
      default = "/mnt/media";
      description = "Root directory for media storage";
    };
  };
}
