{pkgs ? import <nixpkgs> {}}: let
  patchFiles = builtins.attrNames (builtins.readDir ../patches);
  orbitPatchFiles = builtins.filter (name: builtins.match "[0-9][0-9][0-9][0-9]-.*\\.patch" name != null) patchFiles;
  orbitPatches = builtins.map (name: ../patches + "/${name}") (builtins.sort builtins.lessThan orbitPatchFiles);

  version = "1.56.1";

  commit = "f4a54346de9a8afb7daa12d90e42ef34daf033b0";
  date = "2026-06-03T19:01:14Z";

  src = pkgs.fetchFromGitHub {
    owner = "fleetdm";
    repo = "fleet";
    rev = commit;
    sha256 = "sha256-Cr2UThQKWD3q49B7AYVBx3MTb+VD71c6OJcxDSRdr30=";
  };

  vendorHash = "sha256-O3sRDnywVKSSIRnX3LvmM2CGrvqnBXNK0qReemb3r/M=";

  goFlags = ["-buildvcs=false"];
  ldflags = [
    "-s"
    "-w"
    "-X=github.com/fleetdm/fleet/v4/orbit/pkg/build.Version=${version}"
    "-X=github.com/fleetdm/fleet/v4/orbit/pkg/build.Commit=${commit}"
    "-X=github.com/fleetdm/fleet/v4/orbit/pkg/build.Date=${date}"
  ];
in {
  orbit = pkgs.buildGoModule {
    pname = "fleet-orbit";
    inherit
      version
      src
      vendorHash
      goFlags
      ldflags
      ;

    env.CGO_ENABLED = "1";
    subPackages = ["orbit/cmd/orbit"];

    passthru.updateScript = ../update.sh;

    installPhase = ''
      install -Dm755 $GOPATH/bin/orbit $out/bin/orbit
      install -Dm644 orbit/LICENSE $out/share/licenses/fleet-orbit/LICENSE
    '';

    patches = orbitPatches;
  };

  fleet-desktop = pkgs.buildGoModule {
    pname = "fleet-desktop";
    inherit
      version
      src
      vendorHash
      goFlags
      ldflags
      ;

    env.CGO_ENABLED = "1";
    subPackages = ["orbit/cmd/desktop"];

    passthru.updateScript = ../update.sh;

    installPhase = ''
      install -Dm755 $GOPATH/bin/desktop $out/bin/fleet-desktop
      install -Dm644 orbit/LICENSE $out/share/licenses/fleet-desktop/LICENSE
    '';
  };
}
