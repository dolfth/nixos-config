{ ... }:

{
  imports = [
    ./local.nix
    ./frame-art-changer.nix
    ./gatus.nix
    ./jellyplex-watched.nix
    ./media.nix
    ./music-curate.nix
    ./samba.nix
    ./services.nix
    ./slskd.nix
    # Disabled 2026-05-27: soularr re-download loop filled failed_imports with
    # 767 GB / 517 dupes (import failures never unmonitor the album, so every
    # run re-grabs a different user's copy). Rethinking the approach before re-enabling.
    # ./soularr.nix
    ./syncthing.nix
    ./unifi-backup.nix
  ];
}
