{...}: {
  lib,
  config,
  ...
}: let
  inherit (lib) mkDefault mkIf;
in {
  options.stylix.targets.niri.enable = (config.lib.stylix.mkEnableTarget) "niri" true;

  config = mkIf config.stylix.targets.niri.enable {
    programs.niri.settings = {
      cursor.size = mkDefault config.stylix.cursor.size;
      cursor.theme = mkDefault config.stylix.cursor.name;
      layout.focus-ring.enable = mkDefault false;
      layout.border = with config.lib.stylix.colors; {
        enable = mkDefault true;
        active-color = mkDefault "#${base0A}";
        inactive-color = mkDefault "#${base03}";
      };
    };
  };
}
