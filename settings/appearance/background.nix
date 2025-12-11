{
  lib,
  kdl,
  niri-flake-internal,
  toplevel-options,
}:

let
  inherit (lib) types;

  inherit (niri-flake-internal)
    fmt
    nullable
    ;

in
[
  {
    overview = {
      options.backdrop-color = nullable types.str // {
        description = ''
          Set the backdrop color behind workspaces in the overview. The backdrop is also visible between workspaces when switching.

          The alpha channel for this color will be ignored.
        '';
      };
      render = config: [
        (lib.mkIf (config.backdrop-color != null) [
          (kdl.leaf "backdrop-color" config.backdrop-color)
        ])
      ];
    };

    output = {
      options.backdrop-color = nullable types.str // {
        description = ''
          The backdrop color that niri draws for this output. This is visible between workspaces or in the overview.
        '';
      };
      render = config: [
        (lib.mkIf (config.backdrop-color != null) [
          (kdl.leaf "backdrop-color" config.backdrop-color)
        ])
      ];
    };
  }
  {
    layout = {
      options.background-color = nullable types.str // {
        description = ''
          The default background color that niri draws for workspaces. This is visible when you're not using any background tools like swaybg.
        '';
      };
      render = config: [
        (lib.mkIf (config.background-color != null) [
          (kdl.leaf "background-color" config.background-color)
        ])
      ];
    };

    output = {
      options.background-color = nullable types.str // {
        description = ''
          The background color of this output. This is equivalent to launching ${fmt.code "swaybg -c <color>"} on that output, but is handled by the compositor itself for solid colors.
        '';
      };
      render = config: [
        (lib.mkIf (config.background-color != null) [
          (kdl.leaf "background-color" config.background-color)
        ])
      ];
    };
  }
]
