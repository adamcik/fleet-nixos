{ fleetPackages }:
{
  imports = [ ./fleet.nix ];
  _module.args.fleetPackages = fleetPackages;
}
