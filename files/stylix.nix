_:
{
  lib,
  config,
  ...
}:
let
  inherit (lib) mkDefault mkIf;
in
{
  options.stylix.targets.niri.enable = config.lib.stylix.mkEnableTarget "niri" true;

  config = mkIf (config.stylix.enable && config.stylix.targets.niri.enable) {
    programs.niri.settings = {
      cursor = mkIf (config.stylix.cursor != null) {
        size = mkDefault config.stylix.cursor.size;
        theme = mkDefault config.stylix.cursor.name;
      };
      layout.focus-ring.enable = mkDefault false;
      layout.border = with config.lib.stylix.colors.withHashtag; {
        enable = mkDefault true;
        active = mkDefault { color = base0D; };
        inactive = mkDefault { color = base03; };
      };
    };
  };
}
