{pkgs,modulesPath,...}: {
  imports = [
    "${modulesPath}/installer/cd-dvd/installation-cd-minimal.nix"
  ];
  nixpkgs.hostPlatform = "x86_64-linux";
  # reverie-os split test — verifies meta -> iso forward sync
}
