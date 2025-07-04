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
      x86_64-linux = "sha256-M+8l6NGnDjSfxraeohUGuD7DejEoO5lKJLs+cHC85ow=";
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
    message = " Adriel is here Could not find ${name} in the store. Please see ${url}.";
    name = "fleet-osquery_${version}_${platform}.deb";
    url = "https://gitlab.com/proglottis/gitlab-team-nix/-/blob/main/README.md";
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
