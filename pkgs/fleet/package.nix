{ stdenv
, requireFile
, dpkg
, makeWrapper
,
}:
let
  inherit (stdenv.hostPlatform) system;
  throwSystem = throw "Unsupported system for fleet: ${system}";

  version = "1.40.1";
  variant = "-ubuntu-workstation";

  platform =
    {
      x86_64-linux = "amd64";
      # aarch64-linux = "arm64";
    }.${system} or throwSystem;

  platformDir = if system == "x86_64-linux" then "linux" else "linux-${platform}";

  hash =
    {
      # get hash with `nix hash file ~/downloads/fleet-osquery_1.27.0_arm64.deb`
      x86_64-linux = "sha256-tQtbvSBEKUROJtRX5f0Fg1I2pBfxnvLMJ6v9AOH0itw=";
      # aarch64-linux = "...";
    }.${system} or throwSystem;
in
stdenv.mkDerivation rec {
  pname = "fleet";
  inherit version;

  nativeBuildInputs = [
    dpkg
    makeWrapper
  ];

  src = requireFile rec {
    message = "Could not find ${name} in the store. Please see the company docs.";
    name = "fleet-osquery${variant}_${version}_${platform}.deb";
    inherit hash;
  };

  installPhase = ''
    runHook preInstall

    mkdir -p $out
    cp -r ./* $out

    makeWrapper "$out/opt/orbit/bin/orbit/${platformDir}/stable/orbit" "$out/bin/orbit"
    makeWrapper "$out/opt/orbit/bin/osqueryd/${platformDir}/stable/osqueryd" "$out/bin/osqueryd"

    runHook postInstall
  '';
}
