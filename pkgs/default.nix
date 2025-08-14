{ pkgs, ... }: {
  orbit = pkgs.callPackage ./orbit.nix { };
  fleet-desktop = pkgs.callPackage ./fleet-desktop.nix { };
}
