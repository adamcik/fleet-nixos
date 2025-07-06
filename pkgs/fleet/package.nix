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
      # get hash with `nix hash file ~/downloads/fleet-osquery_1.27.0_arm64.deb`
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
    message = "Could not find ${name} in the store. Please see ${url}.";
    name = "fleet-osquery_${version}_${platform}.deb";
    url = "";
    inherit hash;
  };

  # Unpack the .deb source manually since we are not using a standard source type
  sourceRoot = ".";

  installPhase = ''
    runHook preInstall

    # Extract the debian package content into the current directory
    dpkg-deb -x $src .

    # Create the directory structure that orbit expects for auto-updates
    install -d $out/opt/orbit/bin/orbit
    install -d $out/opt/orbit/bin/osqueryd
    install -d $out/bin

    # Move the binaries from their original location in the .deb
    # to the location expected by the application.
    install -m 755 ./opt/orbit/bin/orbit/${platformDir}/stable/orbit $out/opt/orbit/bin/orbit/orbit
    install -m 755 ./opt/orbit/bin/osqueryd/${platformDir}/stable/osqueryd $out/opt/orbit/bin/osqueryd/osqueryd

    # Create wrappers in $out/bin pointing to the new, corrected locations
    makeWrapper "$out/opt/orbit/bin/orbit/orbit" "$out/bin/orbit"
    makeWrapper "$out/opt/orbit/bin/osqueryd/osqueryd" "$out/bin/osqueryd"

    runHook postInstall
  '';
}
