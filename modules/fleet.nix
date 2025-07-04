{
  gitlabPackages,
  pkgs,
  config,
  lib,
  ...
}:
let
  cfg = config.services.fleet;
in
{
  options.services.fleet = {
    enable = lib.mkEnableOption "fleet";
    package = lib.mkPackageOption gitlabPackages.${pkgs.stdenv.hostPlatform.system} "fleet" { };
  };

  config = lib.mkIf cfg.enable {
    environment = {
      systemPackages = [ cfg.package ];
      # This file contains environment variables needed by both the daemon and the GUI
      etc."default/orbit".source = "${cfg.package}/etc/default/orbit";
    };

    # 1. The system service for the background daemon
    systemd.services.orbit = {
      description = "Orbit osquery daemon";
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];

      serviceConfig = {
        # Run the daemon directly. We add '--disable-desktop' to prevent it
        # from trying to launch the GUI, which causes the PAM error.
        ExecStart = ''
          ${cfg.package}/bin/orbit --disable-desktop
        '';

        # The PreStart script is still needed to set up files
        ExecStartPre = pkgs.writeShellScript "orbit-init" ''
          mkdir -p /opt/orbit
          cp "${cfg.package}/opt/orbit/certs.pem" \
             "${cfg.package}/opt/orbit/osquery.flags" \
             "${cfg.package}/opt/orbit/tuf-metadata.json" \
             /opt/orbit
          chmod 600 /opt/orbit/tuf-metadata.json
        '';

        # The daemon needs the environment variables from this file
        EnvironmentFile = "/etc/default/orbit";

        Restart = "always";
        RestartSec = 1;
        KillMode = "control-group";
      };
    };

    # 2. User-level autostart for the GUI application
    # This will launch fleet-desktop for any user that logs into a graphical session.
    xdg.autostart.items.fleet-desktop = {
      name = "Fleet Desktop";
      # The command to run the desktop app
      # We wrap it in a shell to source the environment variables it needs.
      exec = ''
        sh -c '
          # Source the same environment variables as the daemon
          if [ -f /etc/default/orbit ]; then
            . /etc/default/orbit
          fi
          # Launch the desktop app
          ${cfg.package}/opt/orbit/bin/desktop/linux/stable/fleet-desktop/fleet-desktop
        '
      '';
      comment = "Fleet endpoint security agent";
    };
  };
}
