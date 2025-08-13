{ fleetPackages
, pkgs
, config
, lib
, ...
}:
let
  cfg = config.services.fleet;

  orbit-fhs = pkgs.buildFHSEnv {
    name = "orbit-fhs";

    targetPkgs = pkgs: [
      pkgs.stdenv.cc.cc
      pkgs.glibc
      pkgs.zlib
      pkgs.pam
      pkgs.shadow
      pkgs.coreutils
    ];

    runScript = "/opt/orbit/orbit --fleet-desktop=false --disable-updates=true";
  };

  fleet-desktop-fhs = pkgs.buildFHSEnv {
    name = "fleet-desktop-fhs";
    targetPkgs =
      pkgs: with pkgs; [
        # GUI and Wayland dependencies from before
        xorg.libX11
        xorg.libXScrnSaver
        libglvnd
        gtk3
        at-spi2-atk
        alsa-lib
        cups
        udev
        wayland
        xwayland
        libxkbcommon
      ];
    runScript = ''
      FLEET_DESKTOP_DEVICE_IDENTIFIER_PATH="/opt/orbit/identifier" \
      S_CERTIFICATES_PATH="/opt/orbit/certs.pem" \
      exec /opt/orbit/bin/desktop/linux/stable/fleet-desktop/fleet-desktop
    '';
  };
in
{
  options.services.fleet = {
    enable = lib.mkEnableOption "fleet";

    package = lib.mkPackageOption fleetPackages.${pkgs.stdenv.hostPlatform.system} "fleet" { };

    endpoint = lib.mkOption {
      type = lib.types.str;
      default = "";
      example = "https://your-fleet.example.com";
      description = "The base URL of the Fleet server. Used by fleetd and as the default for Orbit.";
    };

    # TODO: Add enrol secret and wire up securily with systemd
  };

  config = lib.mkIf cfg.enable {
    environment = {
      systemPackages = [ cfg.package ];
      etc."default/orbit".source = "${cfg.package}/etc/default/orbit";
    };

    systemd.services.orbit = {
      description = "Orbit osquery";

      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];

      serviceConfig = {
        # Execute orbit within the FHS environment
        ExecStart = "${orbit-fhs}/bin/orbit-fhs";

        # TODO: Shouldn't this be handled by the package?
        ExecStartPre = pkgs.writeShellScript "orbit-init" ''
          mkdir -p /opt/orbit
          mkdir -p /opt/orbit/bin/osqueryd/linux/stable
          mkdir -p /opt/orbit/bin/desktop/linux/stable/fleet-desktop
          cp "${cfg.package}/opt/orbit/certs.pem" \
             "${cfg.package}/opt/orbit/osquery.flags" \
             "${cfg.package}/opt/orbit/tuf-metadata.json" \
             "${cfg.package}/opt/orbit/bin/osqueryd/linux/stable/osqueryd" \
             "${cfg.package}/opt/orbit/bin/orbit/linux/stable/orbit" \
             /opt/orbit
          cp "${cfg.package}/opt/orbit/bin/osqueryd/linux/stable/osqueryd" /opt/orbit/bin/osqueryd/linux/stable/osqueryd
          cp "${cfg.package}/opt/orbit/bin/desktop/linux/stable/fleet-desktop/fleet-desktop" /opt/orbit/bin/desktop/linux/stable/fleet-desktop/fleet-desktop
          chmod 600 /opt/orbit/tuf-metadata.json
        '';

        TimeoutStartSec = 0;
        EnvironmentFile = "/etc/default/orbit";
        Restart = "always";
        RestartSec = 1;
        KillMode = "control-group";
        KillSignal = "SIGTERM";
        CPUQuota = "20%";

        Environment =
          (lib.optionals (cfg.endpoint != null) [ "ORBIT_FLEET_URL=${cfg.endpoint}" ]);

      };
    };

    systemd.user.services."fleet-desktop" = {
      description = "Fleet Desktop GUI";
      after = [
        "graphical-session.target"
        "orbit.service"
      ];
      wantedBy = [ "graphical-session.target" ];

      serviceConfig = {
        ExecStart = "${fleet-desktop-fhs}/bin/fleet-desktop-fhs";
        Restart = "on-failure";
        RestartSec = 10;

        Environment =
          (lib.optionals (cfg.endpoint != null) [ "FLEET_DESKTOP_FLEET_URL=${cfg.endpoint}" ]);
      };
    };
  };
}
