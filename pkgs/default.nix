{pkgs ? import <nixpkgs> {}}: let
  patchFiles = builtins.attrNames (builtins.readDir ../patches);
  orbitPatchFiles = builtins.filter (name: builtins.match "[0-9][0-9][0-9][0-9]-.*\\.patch" name != null) patchFiles;
  orbitPatches = builtins.map (name: ../patches + "/${name}") (builtins.sort builtins.lessThan orbitPatchFiles);

  version = "1.56.2";

  commit = "4f8ff83454f2aaf2534c0eec8ec6fc44a2c21be2";
  date = "2026-06-04T17:58:22Z";

  src = pkgs.fetchFromGitHub {
    owner = "fleetdm";
    repo = "fleet";
    rev = commit;
    sha256 = "sha256-ny+KYooXL+e0fLR1HwOQxFsmpdLDi72upjGa3iLLX0o=";
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
