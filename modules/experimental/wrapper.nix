{
  config,
  lib,
  ...
}:
let
  niri-flake-settings = import ../../settings;
in
{
  _class = "wrapper";
  options = {
    settings = lib.mkOption {
      type = niri-flake-settings.make-type {
        inherit (config) pkgs;
        inherit lib;
        modules = [ { _module.filename = "user-config.kdl"; } ];
      };
      description = ''
        niri config
        see https://sodiboo.github.io/niri-flake/settings.html for available options
      '';
    };
    settings-validation-package = lib.mkOption {
      type = lib.types.nullOr lib.types.package;
      default = config.package;
    };
  };
  config = {
    env.NIRI_CONFIG =
      if config.settings-validation-package == null then
        "${config.settings}"
      else
        config.settings.validated { package = config.settings-validation-package; };
    package = config.pkgs.niri;

    meta = {
      maintainers = [
        lib.maintainers.sodiboo
        {
          name = "holly";
          github = "hollymlem";
          githubId = 35699052;
        }
      ];
      platforms = lib.platforms.all;
    };
  };
}
