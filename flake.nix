# /etc/nixos/flake.nix
{
  description = "flake for nwa";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    
    nixvim = {
      url = "github:nix-community/nixvim";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { nixpkgs, nixvim, ... } @inputs: {
    nixosConfigurations = {
      nwa = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
	specialArgs = { inherit inputs; };
        modules = [
	  ./configuration.nix
	  ./hardware-configuration.nix
        ];
      };
    };
  };
}
