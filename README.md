# gitlab-team-nix

## Usage

1. Download the [fleet package](https://gitlab.com/gitlab-com/gl-security/corp/tooling/fleet-builds/-/releases) to store:
   ```shell
   nix-store --add-fixed sha256 "fleet-osquery_<version>_<arch>.deb"
   ```

2. Add flake as input:
   ```nix
   gitlab-team-nix = {
       url = "gitlab:proglottis/gitlab-team-nix";
       inputs.nixpkgs.follows = "nixpkgs";
   };
   ```

3. Import module:
   ```nix
   imports = [
     inputs.gitlab-team-nix.nixosModules.gitlab
   ];
   ```

4. Enable services:
   ```nix
   services.fleet.enable = true;
   ```
