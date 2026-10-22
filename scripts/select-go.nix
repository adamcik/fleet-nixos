# Select only compilers supplied by the locked nixpkgs. Keeping this independent
# of the package source lets the updater repair a stale source hash first.
{
  pkgs,
  requiredVersion,
  currentVersion,
}: let
  lib = pkgs.lib;
  names = builtins.filter (name: builtins.match "go_[0-9]+_[0-9]+" name != null) (builtins.attrNames pkgs);
  inspect = name: let
    evaluated = builtins.tryEval pkgs.${name}.version;
  in
    if evaluated.success
    then {
      attribute = name;
      family = builtins.replaceStrings ["_"] ["."] (lib.removePrefix "go_" name);
      version = evaluated.value;
    }
    else null;
  available = builtins.filter (compiler:
    compiler
    != null
    && builtins.match "[0-9]+\\.[0-9]+(\\.[0-9]+)?" compiler.version != null
    && lib.versionAtLeast compiler.version requiredVersion) (map inspect names);
  current = builtins.filter (compiler: compiler.family == currentVersion) available;
  ordered = builtins.sort (a: b: lib.versionOlder a.version b.version) available;
in
  if current != []
  then builtins.head current
  else if ordered != []
  then builtins.head ordered
  else null
