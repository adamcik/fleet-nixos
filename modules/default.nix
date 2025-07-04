{ fleet-nixos }:
{
  imports = [ ./fleet.nix ];
  _module.args.fleet-nixos = fleet-nixos;
}
