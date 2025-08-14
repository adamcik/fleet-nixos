{ pkgs ? import <nixpkgs> { } }:

let
  meta = builtins.fromJSON (builtins.readFile ./info.json);
in
pkgs.buildGoModule {
  pname = "fleet-desktop";
  version = meta.version;

  src = pkgs.fetchFromGitHub {
    owner = "fleetdm";
    repo = "fleet";
    rev = "orbit-v${meta.version}";
    sha256 = meta.sha256;
  };

  vendorHash = meta.vendorHash;

  buildFlagsArray = [
    "-trimpath"
    "-buildvcs=false"
    "-ldflags=-s -w -X github.com/fleetdm/fleet/v4/orbit/pkg/build.Version=${meta.version} -X github.com/fleetdm/fleet/v4/orbit/pkg/build.Commit=${meta.version}"
  ];

  subPackages = [ "orbit/cmd/desktop" ];
  env.CGO_ENABLED = "1";

  installPhase = ''
    install -Dm755 $GOPATH/bin/desktop $out/bin/fleet-desktop
    install -Dm644 orbit/LICENSE $out/share/licenses/fleet-desktop/LICENSE
  '';
}
