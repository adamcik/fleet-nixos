{
  description = "fleet-nixos development flake";

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

        programs = {
          actionlint.enable = true;
          alejandra.enable = true;
          prettier.enable = true;
          gofmt.enable = true;
          prettier.settings = {
            printWidth = 0;
          };
        };

        settings.formatter.prettier.includes = [
          "*.json"
        ];
      });
  in {
    formatter = forAllSystems (system: treefmtEval.${system}.config.build.wrapper);

    checks = forAllSystems (system: {
      formatting = treefmtEval.${system}.config.build.check self;
    });

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
