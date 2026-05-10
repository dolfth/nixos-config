{ config, pkgs, ... }:

let
  udmHost = "192.168.0.1";
  udmUser = "root";
  udmBackupDir = "/data/unifi/data/backup/autobackup";
  localDir = "/backup/unifi";
in
{
  sops.secrets.unifi_backup_ssh_key = {
    owner = "unifi-backup";
    group = "unifi-backup";
    mode = "0400";
  };

  sops.secrets.unifi_known_hosts = {
    owner = "unifi-backup";
    group = "unifi-backup";
    mode = "0400";
  };

  users.users.unifi-backup = {
    isSystemUser = true;
    group = "unifi-backup";
    home = localDir;
  };
  users.groups.unifi-backup = {};

  systemd.tmpfiles.rules = [
    "d ${localDir} 0750 unifi-backup unifi-backup -"
    "d ${localDir}/autobackup 0750 unifi-backup unifi-backup -"
  ];

  systemd.services.unifi-backup = {
    description = "Pull UniFi UDM Pro backups via scp";
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    serviceConfig = {
      Type = "oneshot";
      User = "unifi-backup";
      Group = "unifi-backup";
    };
    script = ''
      set -euo pipefail
      staging=${localDir}/.staging
      rm -rf "$staging"
      mkdir -p "$staging"

      ${pkgs.openssh}/bin/scp -rp \
        -i ${config.sops.secrets.unifi_backup_ssh_key.path} \
        -o UserKnownHostsFile=${config.sops.secrets.unifi_known_hosts.path} \
        -o StrictHostKeyChecking=yes \
        ${udmUser}@${udmHost}:${udmBackupDir} "$staging/"

      ${pkgs.rsync}/bin/rsync -a --delete \
        "$staging/autobackup/" ${localDir}/autobackup/

      rm -rf "$staging"
    '';
  };

  systemd.timers.unifi-backup = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "*-*-* 01:33:00";
      Persistent = true;
    };
  };
}
