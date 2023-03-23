{ inputs, lib, ... }:
{
  nix = {
    settings = {
      trusted-users = [ "root" "@wheel" ];

      extra-substituters = [
        "https://elxreno.cachix.org"
      ];
      extra-trusted-public-keys = [
        "elxreno.cachix.org-1:ozSPSY5S3/TpbcXi+/DdtSj1JlK3CPz3G+F92yRBXDQ="
      ];
    };

    registry.nixpkgs.flake = inputs.nixpkgs;

    nixPath = lib.mkForce [ "nixpkgs=${inputs.nixpkgs}" ];

    extraOptions = ''
      experimental-features = nix-command flakes
    '';

    gc = {
      automatic = true;
      dates = "daily";
      options = "-d --delete-older-than 7d";
    };
  };
}
