{
  description = "My own infra based on NixOS";

  inputs = {
    nixpkgs.url = "github:ElXreno/nixpkgs/nixos-unstable-cust";

    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils, ... }@inputs:
    let
      inherit (nixpkgs.lib) nixosSystem filterAttrs;
      inherit (builtins) pathExists readFile readDir mapAttrs or;
    in
    {
      nixosConfigurations =
        let
          defaultSystem = "x86_64-linux";

          servers = mapAttrs (path: _: ./servers + "/${path}")
            (filterAttrs (_: t: t == "directory") (readDir ./servers));

          mkSystemArch = configPath:
            let
              systemPath = configPath + "/system";
            in
            if pathExists systemPath
            then (readFile systemPath)
            else defaultSystem;

          mkSystem = configPath:
            nixosSystem {
              system = mkSystemArch configPath;
              modules = [ (import configPath) self.nixosModules.common ];
              specialArgs = { inherit inputs; };
            };
        in
        mapAttrs (_: path: mkSystem path) servers;

      nixosModules = import ./modules;
    } // flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
      in
      {
        packages = {
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
          in
          pkgs.mkShell {
            buildInputs = with pkgs; [
              azure-cli
              tf
            ];

            shellHook = ''
              export TOP_LEVEL_DIR=$(${pkgs.git}/bin/git rev-parse --show-toplevel)
              export TERRAFORM_DIR="$TOP_LEVEL_DIR/terraform"
            '';
          };
      }
    );
}
