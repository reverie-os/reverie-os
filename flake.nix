{
  description = "Reverie OS meta repo — aggregator over split flakes";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";

    # Local splits (path inputs). Each split repo keeps an identical
    # flake.nix with github: URLs; here we rewire siblings to local paths.
    # To add a split: add `foo.url = "path:./foo";` + follows lines.
    iso.url = "path:./iso";
    iso.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nixpkgs, iso }: {
    inherit (iso) nixosConfigurations packages;
  };
}
