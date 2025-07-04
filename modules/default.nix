{gitlabPackages}: {
  imports = [./fleet.nix];
  _module.args.gitlabPackages = gitlabPackages;
}
