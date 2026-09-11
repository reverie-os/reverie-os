{ pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
  ];

  nixpkgs.hostPlatform = "x86_64-linux";

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.hostName = "reverie";

  # Basic minimal system — expand with modules as Reverie takes shape.
  environment.systemPackages = with pkgs; [
    vim
    git
  ];

  system.stateVersion = "25.05";
}
