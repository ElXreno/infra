{
  description = "My own infra based on NixOS";

  inputs = {
    nixpkgs.url = "github:ElXreno/nixpkgs/nixos-unstable-cust";

    deploy-rs.url = "github:serokell/deploy-rs";
    deploy-rs.inputs.nixpkgs.follows = "nixpkgs";

    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, deploy-rs, flake-utils, ... }@inputs:
    let
      inherit (nixpkgs.lib) nixosSystem filterAttrs;
      inherit (builtins) pathExists readFile readDir mapAttrs or fromJSON;
    in
    {
      nixosConfigurations =
        let
          defaultSystem = "x86_64-linux";

          servers = mapAttrs (path: _: path)
            (filterAttrs (_: t: t == "directory") (readDir ./servers));

          mkSystemArch = hostname:
            let
              systemPath = (./servers + "/${hostname}") + "/system";
            in
            if pathExists systemPath
            then (readFile systemPath)
            else defaultSystem;

          mkSystem = hostname:
            nixosSystem {
              system = mkSystemArch hostname;
              modules = [ (import (./servers + "/${hostname}")) self.nixosModules.common ({ config.networking.hostName = hostname; }) ];
              specialArgs = { inherit inputs; };
            };
        in
        mapAttrs (_: path: mkSystem path) servers;

      nixosModules = import ./modules;

      deploy = {
        user = "deploy";
        nodes =
          let
            # TODO: Really rewrite this piece
            targets = fromJSON (readFile ./targets.json);
          in
          mapAttrs
            (_: nixosConfig: {
              hostname =
                "${toString targets."${nixosConfig.config.networking.hostName}_ipv4"}";

              profiles.system.user = "root";
              profiles.system.path =
                deploy-rs.lib.${nixosConfig.pkgs.system}.activate.nixos nixosConfig;
            })
            self.nixosConfigurations;
      };
    } // flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
      in
      {
        packages = {
          # TODO: Don't try to eval for unsupported arches
          # TODO: Build all used arches to $out
          azure-image = (import "${nixpkgs}/nixos/lib/eval-config.nix" {
            inherit system;
            modules = [
              "${nixpkgs}/nixos/modules/virtualisation/azure-image.nix"
              self.nixosModules.common

              # Reduce image size
              ({
                documentation.enable = false;
                documentation.nixos.enable = false;
                fonts.fontconfig.enable = false;
                programs.bash.enableCompletion = false;
                programs.command-not-found.enable = false;
              })
            ];
            specialArgs = { inherit inputs; };
          }).config.system.build.azureImage;
        };

        devShells.default =
          let
            terraform-with-plugins = (pkgs.terraform.withPlugins (p: [ p.azurerm p.null ]));
            tf = (pkgs.writeShellScriptBin "tf" ''
              ${terraform-with-plugins}/bin/terraform -chdir="$TERRAFORM_DIR" $@
            '');
            tfout = (pkgs.writeShellScriptBin "tfout" ''
              ${tf}/bin/tf apply -refresh-only -auto-approve
              ${tf}/bin/tf output -json | ${pkgs.jq}/bin/jq 'map_values(.value)' | ${pkgs.coreutils}/bin/tee "$TOP_LEVEL_DIR/targets.json"
            '');
          in
          pkgs.mkShell {
            buildInputs = with pkgs; [
              deploy-rs.packages.${system}.deploy-rs
              azure-cli
              tf
              tfout
            ];

            shellHook = ''
              export TOP_LEVEL_DIR=$(${pkgs.git}/bin/git rev-parse --show-toplevel)
              export TERRAFORM_DIR="$TOP_LEVEL_DIR/terraform"
            '';
          };
      }
    );
}
