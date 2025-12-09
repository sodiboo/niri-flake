pkgs: package: config:
pkgs.runCommand "config.kdl"
  {
    inherit config;
    passAsFile = [ "config" ];
    buildInputs = [ package ];
  }
  ''
    niri validate -c $configPath
    cp $configPath $out
  ''
