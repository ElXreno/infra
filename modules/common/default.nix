{ ... }:
{
  imports = [
    ./nix.nix
    ./openssh.nix
    ./users.nix
  ];

  system.stateVersion = "22.05";
}
