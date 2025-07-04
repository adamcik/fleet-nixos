{
  stdenv,
  requireFile,
  dpkg,
  makeWrapper,
}:
let
  inherit (stdenv.hostPlatform) system;
  throwSystem = throw "Unsupported system for fleet: ${system}";

  version = "1.27.0";

  platform =
    {
      x86_64-linux = "amd64";
      aarch64-linux = "arm64";
    }
    .${system} or throwSystem;

  platformDir = if system == "x86_64-linux" then "linux" else "linux-${platform}";

  hash =
    {
      # get hash with `nix hash file ~/downloads/fleet-osquery_1.41.0_arm64.deb`
      x86_64-linux = "sha256-zWZ4b7JRLk8jPPJRsQt0hq9OqiPe1cdC6ctp5Zd6ryo=";
      aarch64-linux = "sha256-e+xDmkb0nG8AodQPTDhn/ao+L5NMbJApGTCOm3lrfnk=";
    }
    .${system} or throwSystem;
in
stdenv.mkDerivation rec {
  pname = "fleet";
  inherit version;

  nativeBuildInputs = [
    dpkg
    makeWrapper
  ];

  src = requireFile rec {
    message = "Could not find ${name} in the store. Please see ${url}.";
    name = "fleet-osquery_${version}_${platform}.deb";
    url = "";
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
