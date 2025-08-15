# fleet-nixos

Fleet Orbit and Fleet Desktop integration for NixOS, packaged as a Nix flake.

## Overview

This repository provides NixOS modules and packages for deploying [Fleet
Orbit](https://github.com/fleetdm/fleet/blob/main/orbit/README.md) and Fleet
Desktop on NixOS systems. It builds the latest releases from FleetDM’s GitHub,
applies custom patches for Nix compatibility, and exposes a flexible module for
configuration.

## Features

- **Packages**: Builds and provides `orbit` and `fleet-desktop` binaries.
- **NixOS Module**: Easily enable and configure Fleet Orbit and Fleet Desktop
  via `services.orbit`.
- **Systemd Integration**: Sets up system and user services for Orbit and Fleet
  Desktop.
- **Custom Patches**: Adds extra flags for NixOS compatibility (see below).
- **Update Script**: Automates updating to the latest Fleet Orbit release.

## Installation

1. **Add the flake as an input:**

   ```nix
   inputs.fleet-nix = {
     url = "github:adamcik/fleet-nixos";
     inputs.nixpkgs.follows = "nixpkgs";
   };
   ```

1. **Import the module in your NixOS configuration:**

   ```nix
   imports = [
     inputs.fleet-nix.nixosModules.fleet-nixos
   ];
   ```

## Configuration

Enable the service and configure options under `services.orbit`. **You must set
either `enrollSecret` or `enrollSecretPath`.**

### Example Configuration

```nix
services.orbit = {
  enable = true;
  fleetUrl = "https://your-fleet.example.com";
  # WARNING: use enrollSecretPath for secrets outside nix-store
  enrollSecret = "your-enroll-secret";
  debug = true;
  devMode = false;
  hostIdentifier = "uuid";
  enableScripts = false;
  fleetCertificate = "/etc/ssl/certs/ca-bundle.crt";
  fleetDesktopAlternativeBrowserHost = null;
  fleetManagedHostIdentityCertificate = false;
  endUserEmail = null;
  insecure = false;
};
```

### Configuration Options and Environment Variables

| Option                                | Description                                                                                          |
|---------------------------------------|------------------------------------------------------------------------------------------------------|
| `enable`                              | Enable Fleet Orbit systemd service                                                                   |
| `fleetUrl`                            | Base URL of the Fleet server                       (`ORBIT_FLEET_URL`)                               |
| `enrollSecret`                        | Enroll secret for Fleet server                     (`ORBIT_ENROLL_SECRET`)                           |
| `enrollSecretPath`                    | Path to enroll secret file                         (`ORBIT_ENROLL_SECRET_PATH`)                      |
| `fleetCertificate`                    | Path to Fleet server certificate chain             (`ORBIT_FLEET_CERTIFICATE`)                       |
| `debug`                               | Enable debug logging                               (`ORBIT_DEBUG`)                                   |
| `devMode`                             | Enable development mode                            (`ORBIT_DEV_MODE`)                                |
| `hostIdentifier`                      | Host identifier mode (e.g., "uuid")                (`ORBIT_HOST_IDENTIFIER`)                         |
| `enableScripts`                       | Enable script execution                            (`ORBIT_ENABLE_SCRIPTS`)                          |
| `fleetDesktopAlternativeBrowserHost`  | Alternative browser host for Fleet Desktop         (`ORBIT_FLEET_DESKTOP_ALTERNATIVE_BROWSER_HOST`)  |
| `fleetManagedHostIdentityCertificate` | Use TPM-backed key for Fleet EE (requires license) (`ORBIT_FLEET_MANAGED_HOST_IDENTITY_CERTIFICATE`) |
| `endUserEmail`                        | End user email (experimental)                      (`ORBIT_END_USER_EMAIL`)                          |
| `insecure`                            | Disable TLS certificate verification               (`ORBIT_INSECURE`)                                |

## Design Decisions

Some Orbit flags and environment variables are hardcoded or omitted for NixOS
compatibility:

- **Updates**: All update-related flags are omitted/hardcoded because NixOS manages packages declaratively. Orbit’s auto-update logic is disabled.
- **Keystore**: Always disabled for NixOS to avoid storing secrets in OS-specific keystores.
- **Paths**: State, logs, and osquery DB paths are hardcoded for security and consistency.
- **Channels**: Update channels are not exposed; updates are managed by Nix, not Orbit.
- **Deprecated/Platform-specific flags**: Omitted as not relevant for NixOS.
- **NixOS-specific flags**: Extra flags are added via patches to ensure correct binary usage, log placement, and Fleet Desktop integration.

## Systemd Services

- **systemd.services.orbit**: Runs the Orbit agent as a system service.
- **systemd.user.services.fleet-desktop**: Runs Fleet Desktop as a user service for graphical sessions.

NOTE: Orbit does not log everything to journald. Check `/var/log/orbit/` for logs.

## Patches

Patches in this repo add extra flags to Orbit for NixOS compatibility:

- `NIX_ORBIT_OSQUERYD_PATH`: Ensures the osqueryd binary from the Nix store is used.
- `NIX_ORBIT_OSQUERY_LOG_PATH`: Ensures osquery logs are written to `/var/log/orbit/osquery/`.
- `NIX_ORBIT_WRITE_FLEET_DESKTOP_IDENTIFIER`: Ensures the device identifier is written for Fleet Desktop integration.

These flags are not present upstream and are always set by the module. They
ensure correct binary usage, log placement, and Fleet Desktop integration on
NixOS.

## Updating Fleet Orbit

To update to the latest Fleet Orbit release, run:

```shell
nix-update orbit --flake --use-update-script
```

This will update the version, commit, and date in `pkgs/default.nix`.

## Fleet Desktop

Fleet Desktop is enabled as a user service when Orbit is enabled. It uses the
same configuration and integrates with graphical sessions.

## Troubleshooting & Tips

- **Required**: You must set either `enrollSecret` or `enrollSecretPath`.
- **Debugging**: Set `debug = true` for verbose logs.
- **Secrets**: Use `enrollSecretPath` with sops-nix for secure secret management.
- **Logs**: Check `/var/log/orbit/` for logs.

______________________________________________________________________

For more details on Orbit configuration, see [orbit.go upstream](https://github.com/fleetdm/fleet/blob/main/orbit/cmd/orbit/orbit.go).
