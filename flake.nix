{
  description = "Nixos Fleet Flakes";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
  };

  outputs =
    { self
    , nixpkgs
    , ...
    }:
    let
      systems = [
        "aarch64-linux"
        "i686-linux"
        "x86_64-linux"
        "aarch64-darwin"
        "x86_64-darwin"
      ];

      forAllSystems = nixpkgs.lib.genAttrs systems;
    in
    {
      formatter = forAllSystems (system: nixpkgs.legacyPackages.${system}.alejandra);
      packages = forAllSystems (system: import ./pkgs nixpkgs.legacyPackages.${system});
      nixosModules.fleet-nixos = import ./modules { fleetPackages = self.packages; };
    };
}
