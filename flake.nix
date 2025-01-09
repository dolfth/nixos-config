# /etc/nixos/flake.nix
{
  description = "flake for nwa";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
    nixvim = {
      url = "github:nix-community/nixvim";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = inputs @ {nixpkgs, flake-parts, ...}:
    flake-parts.lib.mkFlake {inherit inputs;} {
      flake = {
        nixosConfigurations = {
          nwa = nixpkgs.lib.nixosSystem {
            system = "x86_64-linux";
            specialArgs = {inherit inputs;};
            modules = [
              ./configuration.nix
              ./hardware-configuration.nix
            ];
          };
        };
      };
      systems = ["x86_64-linux"];
      perSystem = {
        config,
        self',
        inputs',
        pkgs,
        system,
        ...
      }: {};
    };
}

