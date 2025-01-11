{
  description = "NixOS configuration with flakes";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    
    nixarr.url = "github:rasmus-kirk/nixarr";

    nixvim = {
      url = "github:nix-community/nixvim";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    sops-nix.url = "github:Mic92/sops-nix";
  };

  outputs = { self, nixpkgs, nixarr, nixvim, sops-nix, ... }@inputs: {
    nixosConfigurations.nwa = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      specialArgs = { inherit inputs; };
      modules = [
        ./configuration.nix
        nixarr.nixosModules.default
	nixvim.nixosModules.nixvim
        sops-nix.nixosModules.sops
      ];
    };
  };
}
