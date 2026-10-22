{pkgs ? import <nixpkgs> {}}: let
  buildGoModule = pkgs.buildGo127Module;
  patchFiles = builtins.attrNames (builtins.readDir ../patches);
  orbitPatchFiles = builtins.filter (name: builtins.match "[0-9][0-9][0-9][0-9]-.*\\.patch" name != null) patchFiles;
  orbitPatches = builtins.map (name: ../patches + "/${name}") (builtins.sort builtins.lessThan orbitPatchFiles);

  version = "1.62.0";

  commit = "06c052b28de318c9ef2704d2e387ebd9f7f3dfa2";
  date = "2026-10-19T13:50:14Z";

  src = pkgs.fetchFromGitHub {
    owner = "fleetdm";
    repo = "fleet";
    rev = commit;
    sha256 = "sha256-79V5YHvqFW+rDNGux1jma/+2Z6oIQx7aET0oJ9dkT9o=";
  };

  vendorHash = "sha256-lU1IGly/9AbPuO8uNFp6vyMYS/euxefe0BOL9QmhlR4=";

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
