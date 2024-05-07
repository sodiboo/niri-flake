{...}: {
  lib,
  config,
  ...
}: let
  inherit (lib) mkDefault mkEnableOption mkIf;
in {
  options.stylix.targets.niri.enable =
    if (config.lib ? stylix)
    then (config.lib.stylix.mkEnableTarget) "niri" true
    else mkEnableOption "niri";

  config = mkIf config.stylix.targets.niri.enable {
    programs.niri.settings = {
      cursor.size = mkDefault config.stylix.cursor.size;
      cursor.theme = mkDefault config.stylix.cursor.name;
      layout.focus-ring.enable = mkDefault false;
      layout.border = with config.lib.stylix.colors; {
        enable = mkDefault true;
        active = mkDefault {color = "#${base0A}";};
        inactive = mkDefault {color = "#${base03}";};
      };
    };
  };
}
