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
    lib = nixpkgs.lib;
    forAllSystems =
      lib.genAttrs
      [
        "aarch64-linux"
        "i686-linux"
        "x86_64-linux"
        "aarch64-darwin"
        "x86_64-darwin"
      ];
    requiredGoVersionForOrbit = system: let
      src = self.packages.${system}.orbit.src;
      goModLines = lib.splitString "\n" (builtins.readFile (src + "/go.mod"));
      goVersionLine = builtins.head (builtins.filter (line: lib.hasPrefix "go " line) goModLines);
    in
      lib.removePrefix "go " goVersionLine;
  in {
    packages = forAllSystems (
      system:
        import ./pkgs {
          pkgs = nixpkgs.legacyPackages.${system};
        }
    );

    checks = forAllSystems (system:
      self.packages.${system}
      // {
        orbit-go-version = let
          pkgs = nixpkgs.legacyPackages.${system};
          requiredVersion = requiredGoVersionForOrbit system;
          selectedVersion = pkgs.go_1_26.version;
        in
          assert lib.assertMsg (lib.versionAtLeast selectedVersion requiredVersion)
          "fleet orbit requires Go ${requiredVersion}, but pinned nixpkgs provides ${selectedVersion}";
          pkgs.runCommand "orbit-go-version" {
            requiredVersion = requiredVersion;
            selectedVersion = selectedVersion;
          } ''
            touch "$out"
          '';
      });

    nixosModules.fleet-nixos = import ./modules {
      fleetPackages = self.packages;
    };
  };
}
