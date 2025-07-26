{
  fleetPackages,
  pkgs,
  config,
  lib,
  ...
}:
let
  cfg = config.services.fleet;

  # Create an FHS environment for the orbit executable
  orbit-fhs = pkgs.buildFHSEnv {
    name = "orbit-fhs";

    # Add dependencies needed by the orbit executable AND its children (like sudo)
    targetPkgs = pkgs: [
      pkgs.stdenv.cc.cc
      pkgs.glibc
      pkgs.zlib
      pkgs.pam
      pkgs.shadow
      pkgs.coreutils
    ];

    # runScript = "${cfg.package}/opt/orbit/orbit --fleet-desktop=false --disable-updates=true";
    runScript = "/opt/orbit/orbit --fleet-desktop=true --disable-updates=true";
  };
in
{
  options.services.fleet = {
    enable = lib.mkEnableOption "fleet";
    package = lib.mkPackageOption fleetPackages.${pkgs.stdenv.hostPlatform.system} "fleet" { };
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
        ExecStartPre = pkgs.writeShellScript "orbit-init" ''
          mkdir -p /opt/orbit
          mkdir -p /opt/orbit/bin/osqueryd/linux/stable
          cp "${cfg.package}/opt/orbit/certs.pem" \
             "${cfg.package}/opt/orbit/osquery.flags" \
             "${cfg.package}/opt/orbit/tuf-metadata.json" \
             "${cfg.package}/opt/orbit/bin/osqueryd/linux/stable/osqueryd" \
             "${cfg.package}/opt/orbit/bin/orbit/linux/stable/orbit" \
             "${cfg.package}/opt/orbit/identifier" \
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
      };
    };
  };
}
