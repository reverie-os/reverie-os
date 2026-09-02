{
  description = "Reverie OS ISO builder. bundles the required packages and the Reverie Installer inside the ISO";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";
  };

  outputs = {self, nixpkgs, ...}@inputs: {
    nixosConfigurations = {
      iso = nixpkgs.lib.nixosSystem {
        specialArgs = { inherit inputs; };
        modules = [
          ./iso.nix
        ];
      };
    };
    packages.x86_64-linux.iso = self.nixosConfigurations.iso.config.system.build.isoImage;
  };
}
