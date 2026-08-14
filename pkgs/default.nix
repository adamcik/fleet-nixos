{pkgs ? import <nixpkgs> {}}: let
  buildGoModule = pkgs.buildGo126Module;
  patchFiles = builtins.attrNames (builtins.readDir ../patches);
  orbitPatchFiles = builtins.filter (name: builtins.match "[0-9][0-9][0-9][0-9]-.*\\.patch" name != null) patchFiles;
  orbitPatches = builtins.map (name: ../patches + "/${name}") (builtins.sort builtins.lessThan orbitPatchFiles);

  version = "1.59.0";

  commit = "c9c8bff2fbad08d6a8e581f409d57e5acc633861";
  date = "2026-08-13T19:44:12Z";

  src = pkgs.fetchFromGitHub {
    owner = "fleetdm";
    repo = "fleet";
    rev = commit;
    sha256 = "sha256-JkEiq3V6VFKQYAxfD9YAmpJW978Hp52X5btrZpPjtxY=";
  };

  vendorHash = "sha256-FJtIK+SQNRpxTQdzPAFQCOy4dLNf7BfLru8Gm3ejtZM=";

  goFlags = ["-buildvcs=false"];
  ldflags = [
    "-s"
    "-w"
    "-X=github.com/fleetdm/fleet/v4/orbit/pkg/build.Version=${version}"
    "-X=github.com/fleetdm/fleet/v4/orbit/pkg/build.Commit=${commit}"
    "-X=github.com/fleetdm/fleet/v4/orbit/pkg/build.Date=${date}"
  ];
in {
  orbit = buildGoModule {
    pname = "fleet-orbit";
    inherit
      version
      src
      vendorHash
      goFlags
      ldflags
      ;

    env = {
      CGO_ENABLED = "1";
      GOTOOLCHAIN = "local";
    };
    subPackages = ["orbit/cmd/orbit"];

    passthru.updateScript = ../update.sh;

    installPhase = ''
      install -Dm755 $GOPATH/bin/orbit $out/bin/orbit
      install -Dm644 orbit/LICENSE $out/share/licenses/fleet-orbit/LICENSE
    '';

    patches = orbitPatches;
  };

  fleet-desktop = buildGoModule {
    pname = "fleet-desktop";
    inherit
      version
      src
      vendorHash
      goFlags
      ldflags
      ;

    env = {
      CGO_ENABLED = "1";
      GOTOOLCHAIN = "local";
    };
    subPackages = ["orbit/cmd/desktop"];

    passthru.updateScript = ../update.sh;

    installPhase = ''
      install -Dm755 $GOPATH/bin/desktop $out/bin/fleet-desktop
      install -Dm644 orbit/LICENSE $out/share/licenses/fleet-desktop/LICENSE
    '';
  };
}
