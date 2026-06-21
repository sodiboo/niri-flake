_:
{ lib, config, ... }:
let
  inherit (lib) mkDefault mkIf;
  inherit (config.lib.stylix.colors.withHashtag)
    base00
    base01
    base03
    base08
    base0D
    ;
in
{
  options.stylix.targets.niri.enable = config.lib.stylix.mkEnableTarget "niri" true;

  config = mkIf (config.stylix.enable && config.stylix.targets.niri.enable) {
    programs.niri.settings = {
      cursor = mkIf (config.stylix.cursor != null) {
        size = mkDefault config.stylix.cursor.size;
        theme = mkDefault config.stylix.cursor.name;
      };
      layout = {
        background-color = base00;
        focus-ring = {
          active = mkDefault { color = base0D; };
          inactive = mkDefault { color = base03; };
          urgent = mkDefault { color = base08; };
        };
        border = {
          active = mkDefault { color = base0D; };
          inactive = mkDefault { color = base03; };
          urgent = mkDefault { color = base08; };
        };
        shadow = {
          color = mkDefault base0D;
          inactive-color = mkDefault base03;
        };
        tab-indicator = {
          active = mkDefault { color = base0D; };
          inactive = mkDefault { color = base03; };
          urgent = mkDefault { color = base08; };
        };
        insert-hint = {
          display = mkDefault { color = base0D + "80"; }; # 80 -> Half Transparent (Default Behaviour)
        };
      };
      overview = {
        backdrop-color = base00;
      };
    };
  };
}
