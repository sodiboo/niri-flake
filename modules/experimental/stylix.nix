{
  lib,
  pkgs,
  config,
  ...
}:
let
  cfg = config.stylix.targets.niri;
  colors = config.lib.stylix.colors.withHashtag;
  niri-flake-settings = import ../../settings;
in
{
  options.stylix.targets.niri = {
    enable = config.lib.stylix.mkEnableTarget "niri" true;

    settings = lib.mkOption {
      type = niri-flake-settings.make-type { inherit lib pkgs; };
      visible = "shallow";
      readOnly = true;
    };
  };

  config = lib.mkMerge [
    {
      stylix.targets.niri.settings = {
        _module.filename = "stylix.kdl";

        cursor = lib.mkIf (config.stylix.cursor != null) {
          size = config.stylix.cursor.size;
          theme = config.stylix.cursor.name;
        };

        layout = lib.genAttrs [ "border" "focus-ring" "tab-indicator" ] (_: {
          active.color = colors.base0D;
          inactive.color = colors.base03;
          urgent.color = colors.base08;
        });
      };
    }
    (lib.mkIf (config.stylix.enable && cfg.enable) {
      programs.niri.settings.includes = lib.mkBefore [ "${cfg.settings}" ];
    })
  ];
}
