# Exercise the actual flake check without fetching or building package sources.
let
  requested = (builtins.fromJSON (builtins.readFile ../orbit.json)).version;
  check = generated: let
    outputs = (import ../flake.nix).outputs {
      self.packages.x86_64-linux.orbit.version = generated;
      nixpkgs = {
        lib = {
          genAttrs = names: f:
            builtins.listToAttrs (map (name: {
                inherit name;
                value = f name;
              })
              names);
          assertMsg = condition: message:
            if condition
            then true
            else throw message;
        };
        legacyPackages.x86_64-linux.runCommand = _name: _attributes: _script: true;
      };
    };
  in
    builtins.tryEval outputs.checks.x86_64-linux.orbit-release-version;
in
  assert (check requested).success;
  assert !(check "stale-artifacts").success; true
