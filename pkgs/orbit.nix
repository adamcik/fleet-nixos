{ pkgs ? import <nixpkgs> { } }:

let
  meta = builtins.fromJSON (builtins.readFile ./info.json);
in
pkgs.buildGoModule {
  pname = "fleet-orbit";
  version = meta.version;

  src = pkgs.fetchFromGitHub {
    owner = "fleetdm";
    repo = "fleet";
    rev = "orbit-v${meta.version}";
    sha256 = meta.sha256;
  };

  vendorHash = meta.vendorHash;

  patches = [
    ./patches/osqueryd-path-override.patch
    ./patches/osquery-log-path.patch
    ./patches/write-identifier.patch
  ];

  goFlags = [ "-buildvcs=false" ];
  ldflags = [
    "-s"
    "-w"
    "-X=github.com/fleetdm/fleet/v4/orbit/pkg/build.Version=${meta.version}"
    "-X=github.com/fleetdm/fleet/v4/orbit/pkg/build.Commit=${meta.commit}"
  ];

  subPackages = [ "orbit/cmd/orbit" ];
  env.CGO_ENABLED = "1";

  installPhase = ''
    install -Dm755 $GOPATH/bin/orbit $out/bin/orbit
    install -Dm644 orbit/LICENSE $out/share/licenses/fleet-orbit/LICENSE
  '';
}
