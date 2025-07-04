{
  pkgs,
  lib,
}: let
  goVersion = pkgs.go_1_24;
  postgresqlVersion = pkgs.postgresql_16;
  pythonVersion = pkgs.python312;
  rubyVersion = pkgs.ruby_3_3;
  nodejsVersion = pkgs.nodejs_20;
in
  pkgs.mkShell {
    packages = with pkgs; [
      # Libraries
      graphicsmagick
      icu
      libkrb5
      libyaml
      libuuid
      openssl
      pcre2
      re2
      zlib
      libpq

      # Tools
      chromedriver
      cmake
      curl
      delve
      exiftool
      git
      gitleaks
      goVersion
      markdownlint-cli2
      meson
      minio
      ninja
      nodejsVersion
      pkg-config
      poetry
      postgresqlVersion
      pythonVersion
      redis
      rubyVersion
      runit
      rustc
      shellcheck
      vale
      yamllint
      yarn
    ];

    shellHook = ''
      export LD_LIBRARY_PATH="${lib.makeLibraryPath [
        # Required to let Ruby's FFI find locate libcurl.
        pkgs.curl
        # Required to let re2 find libstdc++.so.6.
        pkgs.stdenv.cc.cc.lib

        pkgs.openssl

        pkgs.libpq
      ]}"
      export GOPATH=$PWD/.devenv/go
      export GEM_HOME=$PWD/.devenv/ruby_${rubyVersion.version}
      export GEM_PATH=$GEM_HOME
      export POETRY_VIRTUALENVS_IN_PROJECT=1
      export POETRY_PYTHON_PATH="${pythonVersion}/bin/python"
      export PATH=$GEM_HOME/bin:$PATH
      export PATH=$PWD/bin:$PATH
    '';
  }

