{
  config,
  pkgs,
  lib,
  inputs,
  ...
}:
let
  cfg = config.programs.niri;
  call = lib.flip import {
    inherit
      inputs
      kdl
      settings
      ;
    inherit lib;
  };
  kdl = call ./kdl.nix;
  settings = call ./settings.nix;

  validateConfig = import ./validate-config.nix;

  packageSet = import ./package.nix {
    inherit inputs;
  };
in
{
  imports = [
    settings.module
  ];

  options.programs.niri = {
    package = lib.mkOption {
      type = lib.types.package;
      default = (packageSet pkgs).niri-stable;
      description = "The niri package to use.";
    };
  };

  config.lib.niri = {
    actions = lib.mergeAttrsList (
      map (name: {
        ${name} = kdl.magic-leaf name;
      }) (import ./memo-binds.nix)
    );
  };

  config.xdg.configFile.niri-config = {
    enable = cfg.finalConfig != null;
    target = "niri/config.kdl";
    source = validateConfig pkgs cfg.package cfg.finalConfig;
  };
}
