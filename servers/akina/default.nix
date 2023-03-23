{ inputs, ... }:
{
  imports = [
    inputs.self.nixosModules.azure
  ];
}
