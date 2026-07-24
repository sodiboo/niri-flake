{
  lib,
  pkgs,
  config,
  ...
}:
let
  cfg = config.programs.niri;

  niri-flake-settings = import ../../../settings;
in
{
  options.programs.niri = {
    enable = lib.mkEnableOption "niri's config file";

    settings-validation-package = lib.mkPackageOption pkgs "niri" { nullable = true; };

    settings = lib.mkOption {
      type = niri-flake-settings.make-type {
        inherit lib pkgs;
        modules = [ { _module.filename = "user-config.kdl"; } ];
      };
      default = { };
    };
  };

  config.xdg.configFile.niri-config = {
    target = "niri/config.kdl";
    source =
      if cfg.settings-validation-package == null then
        "${cfg.settings}"
      else
        cfg.settings.validated { package = cfg.settings-validation-package; };
  };
}
