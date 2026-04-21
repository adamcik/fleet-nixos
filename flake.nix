{
  description = "Nixos Fleet Flakes";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
  };

  outputs = {
    self,
    nixpkgs,
    ...
  }: let
    forAllSystems =
      nixpkgs.lib.genAttrs
      [
        "aarch64-linux"
        "i686-linux"
        "x86_64-linux"
        "aarch64-darwin"
        "x86_64-darwin"
      ];
  in {
    packages = forAllSystems (
      system:
        import ./pkgs {
          pkgs = nixpkgs.legacyPackages.${system};
        }
    );

    checks = forAllSystems (system: self.packages.${system});

    nixosModules.fleet-nixos = import ./modules {
      fleetPackages = self.packages;
    };
  };
}
