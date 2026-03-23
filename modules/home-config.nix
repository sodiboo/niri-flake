{
  config,
  pkgs,
  lib,
  ...
}@args:
let
  cfg = config.programs.niri;
  nirilib = import ../lib.nix { inherit lib pkgs; };
in
{
  imports = [
    nirilib.settings.module
  ];

  options.programs.niri = {
    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.niri-stable;
      description = "The niri package to use.";
    };
  };

  config.nixpkgs.overlays = lib.mkIf (!args ? nixosConfig) [
    (import ../overlay.nix)
  ];

  config.lib.niri = {
    actions = lib.mergeAttrsList (
      map (name: {
        ${name} = nirilib.kdl.magic-leaf name;
      }) (import ../memo-binds.nix)
    );
  };

  config.xdg.configFile.niri-config = {
    enable = cfg.finalConfig != null;
    target = "niri/config.kdl";
    source = nirilib.validated-config-for pkgs cfg.package cfg.finalConfig;
  };
}
