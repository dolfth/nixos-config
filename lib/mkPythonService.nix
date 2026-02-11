{ lib }:

{
  name,
  description,
  pythonEnv,
  src,
  entrypoint,
  timerConfig,
  after ? [ "network.target" ],
  wants ? [ "network.target" ],
  extraReadWritePaths ? [],
  extraGroups ? [],
  extraServiceConfig ? {},
  preStart ? null,
}:

{
  users.users.${name} = {
    isSystemUser = true;
    group = name;
    home = "/var/lib/${name}";
    createHome = true;
  } // lib.optionalAttrs (extraGroups != []) {
    inherit extraGroups;
  };

  users.groups.${name} = {};

  systemd.tmpfiles.rules = [
    "d /var/lib/${name} 0750 ${name} ${name} -"
    "d /var/log/${name} 0750 ${name} ${name} -"
  ];

  systemd.services.${name} = {
    inherit description after wants;

    serviceConfig = {
      Type = "oneshot";
      User = name;
      Group = name;
      WorkingDirectory = "/var/lib/${name}";
      ExecStart = "${pythonEnv}/bin/python ${src}/${entrypoint}";

      # Hardening
      NoNewPrivileges = true;
      ProtectSystem = "strict";
      ProtectHome = true;
      PrivateTmp = true;
      ReadWritePaths = [
        "/var/lib/${name}"
        "/var/log/${name}"
      ] ++ extraReadWritePaths;
    } // extraServiceConfig;
  } // lib.optionalAttrs (preStart != null) {
    inherit preStart;
  };

  systemd.timers.${name} = {
    description = "Run ${name} periodically";
    wantedBy = [ "timers.target" ];
    timerConfig = { Persistent = true; } // timerConfig;
  };
}
