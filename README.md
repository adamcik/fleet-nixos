# fleet-nixos package

## Usage

1. Download the fleet package to store:
   ```shell
   nix-store --add-fixed sha256 "fleet-osquery_<version>_<arch>.deb"
   ```

2. Add flake as input:
   ```nix
    fleet-nix = {
      url = "github:AdrielVelazquez/fleet-nixos";
      inputs.nixpkgs.follows = "nixpkgs";
    };
   ```

3. Import module:
   ```nix
   imports = [
    inputs.fleet-nix.nixosModules.fleet-nixos
   ];
   ```

4. Enable services:
   ```nix
   services.fleet.enable = true;
   ```
