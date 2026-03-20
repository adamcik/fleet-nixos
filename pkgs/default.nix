{pkgs ? import <nixpkgs> {}}: let
  version = "1.53.1"; # renovate: orbit

  commit = "f28467a4158e58e3c9b4d335c61f3201d6ef8658";
  date = "2026-03-18T17:14:25Z";

  src = pkgs.fetchFromGitHub {
    owner = "fleetdm";
    repo = "fleet";
    rev = commit;
    sha256 = "sha256-ut1WGYyngr/nf7uKev26ni1wMPTaW5t/YXjl8C5qVjk=";
  };

  vendorHash = "sha256-/6RFtO7BHxi9g59dn84+q/oUEZB8kWppTu2OFq8HHDg=";

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
