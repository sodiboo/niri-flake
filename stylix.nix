_:
{
  lib,
  config,
  ...
}:
let
  inherit (lib) mkDefault mkIf;
  cfg = config.options.stylix.targets.niri;
in
{
  options.stylix.targets.niri = {
    enable = config.lib.stylix.mkEnableTarget "niri" true;
    cursor = {
      enable = lib.mkEnableOption "cursor for niri" // {
        default = true;
        example = false;
      };

      override = lib.mkOption {
        description = "recursively merged with cursor";
        type = lib.types.attrs;
        default = { };
      };
    };
    colors = {
      enable = lib.mkEnableOption "colors for niri" // {
        default = true;
        example = false;
      };

      override = lib.mkOption {
        description = "recursively merged with colors";
        type = lib.types.attrs;
        default = { };
      };
    };
  };

  config = mkIf (config.stylix.enable && cfg.enable) {
    programs.niri.settings = lib.mkMerge [
      {
        cursor =
          let
            cursor' = lib.recursiveUpdate config.stylix.cursor cfg.cursor.override;
          in
          mkIf (config.stylix.cursor != null && cfg.cursor.enable) {
            size = mkDefault cursor'.size;
            theme = mkDefault cursor'.name;
          };
      }
      {
        layout = {
          focus-ring.enable = mkDefault false;
          border = with (lib.recursiveUpdate config.lib.stylix.colors.withHashtag cfg.colors.override); {
            enable = mkDefault true;
            active = mkDefault { color = base0D; };
            inactive = mkDefault { color = base03; };
          };
        };
      }
    ];
  };
}
