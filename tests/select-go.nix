let
  select = import ../scripts/select-go.nix;
  pkgs = {
    lib = {
      versionAtLeast = a: b: builtins.compareVersions a b >= 0;
      versionOlder = a: b: builtins.compareVersions a b < 0;
      removePrefix = prefix: text: builtins.substring (builtins.stringLength prefix) (-1) text;
    };
    go_1_24 = throw "removed compiler alias";
    go_1_26.version = "1.26.7";
    go_1_27.version = "1.27.1";
    go_1_28.version = "1.28.0";
    go_1_29.version = "1.29rc1";
    go.version = "1.26.7";
  };
  choose = requiredVersion: currentVersion:
    select {inherit pkgs requiredVersion currentVersion;};
in
  assert (choose "1.26.0" "1.27").family == "1.27";
  assert (choose "1.27.1" "1.26").family == "1.27";
  assert (choose "1.27.2" "1.27").family == "1.28";
  assert (choose "1.27" "1.24").family == "1.27";
  assert (choose "1.28.1" "1.28") == null;
  assert (choose "1.29.0" "1.27") == null; true
