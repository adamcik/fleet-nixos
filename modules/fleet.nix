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
      systemPackages = [
        cfg.package
        # Add steam-run to the system so the service can find it
        pkgs.steam-run
      ];
      etc."default/orbit".source = "${cfg.package}/etc/default/orbit";
    };

    systemd.services.orbit = {
      description = "Orbit osquery";

      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];

      serviceConfig = {
        # Wrap the original command in steam-run
        ExecStart = "${pkgs.steam-run}/bin/steam-run ${cfg.package}/bin/orbit";

        ExecStartPre = pkgs.writeShellScript "orbit-init" ''
          mkdir -p /opt/orbit
          cp "${cfg.package}/opt/orbit/certs.pem" \
             "${cfg.package}/opt/orbit/osquery.flags" \
             "${cfg.package}/opt/orbit/tuf-metadata.json" \
             /opt/orbit
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
