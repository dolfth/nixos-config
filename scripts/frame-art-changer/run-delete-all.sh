#!/bin/sh
exec nix --extra-experimental-features "nix-command flakes" shell --impure --option sandbox false \
  --expr '(builtins.getFlake "nixpkgs").legacyPackages.x86_64-linux.python312.withPackages (ps: with ps; [ websocket-client requests websockets aiohttp async-timeout ])' \
  -c python3 @deleteAllArtPath@
