{pkgs, ...}: {
  fleet = pkgs.callPackage ./fleet/package.nix {};
}
