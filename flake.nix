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
    apps = forAllSystems (system: let
      pkgs = nixpkgs.legacyPackages.${system};
      updater = pkgs.writeShellApplication {
        name = "update-orbit";
        runtimeInputs = [pkgs.git pkgs.nix pkgs.nix-update pkgs.python3];
        text = ''
          exec python3 ${./scripts/update_orbit.py} "$@"
        '';
      };
    in {
      update-orbit = {
        type = "app";
        program = "${updater}/bin/update-orbit";
        meta.description = "Update an Orbit release and its Go compiler and Nix artifacts";
      };
    });

    packages = forAllSystems (
      system:
        import ./pkgs {
          pkgs = nixpkgs.legacyPackages.${system};
        }
    );

    checks = forAllSystems (system:
      self.packages.${system}
      // {
        orbit-release-version = let
          pkgs = nixpkgs.legacyPackages.${system};
          requested = (builtins.fromJSON (builtins.readFile ./orbit.json)).version;
          generated = self.packages.${system}.orbit.version;
        in
          assert lib.assertMsg (requested == generated)
          "Orbit artifacts are for ${generated}, but orbit.json requests ${requested}; run ./update.sh --version ${requested}";
            pkgs.runCommand "orbit-release-version" {} ''
              touch "$out"
            '';

        updater = let
          pkgs = nixpkgs.legacyPackages.${system};
        in
          pkgs.runCommand "orbit-updater-tests" {
            nativeBuildInputs = [pkgs.python3 pkgs.nix];
            src = self;
          } ''
            cp -r "$src" source
            cd source
            python3 -m unittest discover -s tests -v
            nix-instantiate --store dummy:// --eval --strict --json tests/select-go.nix
            nix-instantiate --store dummy:// --eval --strict --json tests/release-version.nix
            touch "$out"
          '';

        orbit-go-version = let
          pkgs = nixpkgs.legacyPackages.${system};
          requiredVersion = requiredGoVersionForOrbit system;
          selectedVersion = self.packages.${system}.orbit.go.version;
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
