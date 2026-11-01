{pkgs ? import <nixpkgs> {}}: let
  goVersion = "1.27";
  go = pkgs.${"go_" + builtins.replaceStrings ["."] ["_"] goVersion};
  buildGoModule = pkgs.buildGoModule.override {inherit go;};
  patchFiles = builtins.attrNames (builtins.readDir ../patches);
  orbitPatchFiles = builtins.filter (name: builtins.match "[0-9][0-9][0-9][0-9]-.*\\.patch" name != null) patchFiles;
  orbitPatches = builtins.map (name: ../patches + "/${name}") (builtins.sort builtins.lessThan orbitPatchFiles);

  version = "1.63.0";

  commit = "5e2f9163460ac8246bbace9192bcb99e8a2989e3";
  date = "2026-10-30T12:50:17Z";

  src = pkgs.fetchFromGitHub {
    owner = "fleetdm";
    repo = "fleet";
    rev = commit;
    sha256 = "sha256-cKF1nE9kK22EfB0Ky+vp8QaBDYcZ00mwWNU9BJwWAx8=";
  };

  vendorHash = "sha256-mnjllTf4m8Kirx0TKKWzr0haA/zwiZMWYEYRifVeFpQ=";

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
