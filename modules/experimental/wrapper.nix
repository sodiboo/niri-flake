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
  };
  config = {
    env.NIRI_CONFIG = toString (config.settings.validated { package = config.package; });
    filesToPatch = [ "share/systemd/user/niri.service" ];
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
