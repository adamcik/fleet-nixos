# fleet.nix
{
  stdenv,
  lib,
  requireFile,
  dpkg,
  makeWrapper,
  copyDesktopItems,
  makeDesktopItem,

  # --- Hooks ---
  wrapGAppsHook,
  autoPatchelfHook, # Automatically patch ELF binaries

  # --- Dependencies ---
  alsa-lib,
  at-spi2-atk,
  at-spi2-core, # Added dependency for accessibility
  cups,
  dbus, # For inter-process communication
  fontconfig, # For finding fonts
  gsettings-desktop-schemas, # For GTK settings
  gtk3,
  libglvnd, # For OpenGL
  libnotify, # For desktop notifications
  libsecret, # Added dependency for storing secrets
  libuuid,
  libX11,
  libXcomposite,
  libXdamage,
  libXext,
  libXfixes,
  libxkbcommon,
  libXrandr,
  libxshmfence,
  nss,
  nspr,
  noto-fonts, # Provide some default fonts
  pango,
  pipewire, # Often needed for modern audio/video
  webkitgtk_4_1, # Changed from webkitgtk to be explicit
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
      x86_64-linux = "sha256-M+8l6NGnDjSfxraeohUGuD7DejEoO5lKJLs+cHC85ow=";
      aarch64-linux = "sha256-e+xDmkb0nG8AodQPTDhn/ao+L5NMbJApGTCOm3lrfnk=";
    }
    .${system} or throwSystem;

in
stdenv.mkDerivation rec {
  pname = "fleet";
  inherit version;

  src = requireFile rec {
    message = ''
      Could not find ${name} in the store.
      You can download it from: ${url}
      Then, add it to the nix store using:
      nix-store --add-fixed sha256 ${name}
    '';
    name = "fleet-osquery_${version}_${platform}.deb";
    url = "https://github.com/fleetdm/fleet/releases/download/fleet-v${version}/${name}";
    inherit hash;
  };

  nativeBuildInputs = [
    dpkg
    makeWrapper
    copyDesktopItems
    wrapGAppsHook
    autoPatchelfHook # Add the hook
  ];

  # A more comprehensive list of runtime dependencies
  buildInputs = [
    alsa-lib
    at-spi2-atk
    at-spi2-core
    cups
    dbus
    fontconfig
    gsettings-desktop-schemas
    gtk3
    libglvnd
    libnotify
    libsecret
    libuuid
    libX11
    libXcomposite
    libXdamage
    libXext
    libXfixes
    libxkbcommon
    libXrandr
    libxshmfence
    nss
    nspr
    noto-fonts
    pango
    pipewire
    webkitgtk_4_1 # Changed from webkitgtk to be explicit
  ];

  # Help autoPatchelfHook find the libraries
  runtimeDependencies = buildInputs;

  desktopItems = [
    (makeDesktopItem {
      name = "fleet-desktop";
      exec = "fleet-desktop";
      icon = "fleet-desktop";
      comment = "Fleet Desktop for osquery";
      desktopName = "Fleet Desktop";
      genericName = "Device Management";
      categories = [
        "System"
        "Utility"
      ];
    })
  ];

  installPhase = ''
    runHook preInstall

    dpkg-deb -x $src $out

    # --- Create Wrappers for all binaries ---
    # The autoPatchelfHook will run on the original binaries first.
    # Then, makeWrapper will create scripts in $out/bin that call the patched originals.
    # The wrapGAppsHook automatically enhances makeWrapper to add GUI environment variables.

    makeWrapper "$out/opt/orbit/bin/orbit/${platformDir}/stable/orbit" "$out/bin/orbit"
    makeWrapper "$out/opt/orbit/bin/osqueryd/${platformDir}/stable/osqueryd" "$out/bin/osqueryd"
    makeWrapper "$out/opt/orbit/bin/desktop/${platformDir}/stable/fleet-desktop/fleet-desktop" "$out/bin/fleet-desktop"

    # --- Icon Installation ---
    icon_path=$(find $out/opt/orbit/bin/desktop -name "icon.png" | head -n 1)
    if [[ -f "$icon_path" ]]; then
      mkdir -p $out/share/icons/hicolor/512x512/apps
      cp "$icon_path" "$out/share/icons/hicolor/512x512/apps/fleet-desktop.png"
    fi

    runHook postInstall
  '';

  meta = with lib; {
    description = "Fleet osquery manager and desktop UI";
    homepage = "https://fleetdm.com/";
    # license = licenses.unfreeWithRedistribution;
    maintainers = with maintainers; [ ]; # Add your handle here
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
    ];
  };
}
