{ ... }:
{
  imports = [
    ./users.nix
    ./nix.nix
  ];

  system.stateVersion = "22.05";
}
