{pkgs ? import <nixpkgs> {}}: let
  version = "1.52.0"; # renovate: orbit

  src = pkgs.fetchFromGitHub {
    owner = "fleetdm";
    repo = "fleet";
    tag = "orbit-v${version}";
    sha256 = "sha256-4gLJ6U31RZiccRM7EnsybzhMJwnGGitJjcN/uRJPvJw=";
  };

  vendorHash = "sha256-S2rB23qulG1NK8R6zHg0fSkvp10Lwupm4Xf+otSiWro=";
  commit = "490a193a5eb97d2f29769412f0f0f3f805999f63";
  date = "2025-12-12T14:46:25Z";

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

    patches = [
      ../patches/osqueryd-path-override.patch
      ../patches/osquery-log-path.patch
      ../patches/orbit-nixos.patch
      ../patches/scripts-nixos.patch
    ];
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
