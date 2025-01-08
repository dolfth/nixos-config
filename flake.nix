# /etc/nixos/flake.nix
{
  description = "flake for nwa";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs }: {
    nixosConfigurations = {
      nwa = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
	  ./configuration.nix
	   ./hardware-configuration.nix
        ];
      };
    };
  };
}