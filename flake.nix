{
  description = "Nixos Fleet Flakes";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
    treefmt-nix.url = "github:numtide/treefmt-nix";
    treefmt-nix.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = {
    self,
    nixpkgs,
    treefmt-nix,
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
    treefmtEval = forAllSystems (system:
      treefmt-nix.lib.evalModule nixpkgs.legacyPackages.${system} {
        projectRootFile = "flake.nix";
        programs.alejandra.enable = true;
        programs.prettier.enable = true;
        programs.gofmt.enable = true;
      });
  in {
    formatter = forAllSystems (system: treefmtEval.${system}.config.build.wrapper);
    packages = forAllSystems (
      system:
        import ./pkgs {
          pkgs = nixpkgs.legacyPackages.${system};
        }
    );
    checks = forAllSystems (system: let
      pkgs = nixpkgs.legacyPackages.${system};
    in
      {
        formatting = treefmtEval.${system}.config.build.check self;
        flake-checker =
          pkgs.runCommand "flake-checker" {
            nativeBuildInputs = [pkgs.flake-checker];
          } ''
            flake-checker --fail-mode ${self}/flake.lock
            touch $out
          '';
      }
      // self.packages.${system});
    nixosModules.fleet-nixos = import ./modules {
      fleetPackages = self.packages;
    };
    devShells = forAllSystems (
      system: let
        pkgs = nixpkgs.legacyPackages.${system};
      in {
        default = pkgs.mkShell {
          packages = with pkgs; [
            go
            gopls
            gotools
            nix-update
            curl
            jq
            alejandra
          ];
        };
      }
    );
  };
}
