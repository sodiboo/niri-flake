{
  lib,
  kdl,
  hierarchies,
  niri-flake-internal,
  toplevel-options,
  ...
}:

let
  inherit (niri-flake-internal) fmt;
in
[
  (hierarchies.gesture-options.output-level (ctx: {
    options.hot-corners = ctx.nullable "hot-corners" {
      description = ''
        Hot corners allow you to put your mouse in the corner of an output to toggle the overview. This interaction also works while drag-and-dropping.

        By default, the top-left corner is the only hot corner. You can use this option to explicitly set which hot corners you want.

        Individual hot corners cannot be enabled/disabled separately. This option configures all four hot corners at once.
      '';
      type = lib.types.submodule (
        { config, ... }:
        {
          options = {
            top-left = lib.mkOption { type = lib.types.bool; };
            top-right = lib.mkOption { type = lib.types.bool; };
            bottom-left = lib.mkOption { type = lib.types.bool; };
            bottom-right = lib.mkOption { type = lib.types.bool; };

            rendered = lib.mkOption {
              type = kdl.types.kdl-node;
              readOnly = true;
              internal = true;
              visible = false;
            };
          };
          config.rendered = kdl.plain "hot-corners" [
            # if `hot-corners {}` with no children, then `top-left` is implicit.
            # therefore, we must specify `off` in the case of all being disabled.
            (lib.mkIf (builtins.all (x: !x) [
              config.top-left
              config.top-right
              config.bottom-left
              config.bottom-right
            ]) [ (kdl.flag "off") ])
            (lib.mkIf (config.top-left) [ (kdl.flag "top-left") ])
            (lib.mkIf (config.top-right) [ (kdl.flag "top-right") ])
            (lib.mkIf (config.bottom-left) [ (kdl.flag "bottom-left") ])
            (lib.mkIf (config.bottom-right) [ (kdl.flag "bottom-right") ])
          ];
        }
      );
    };
    render = config: [
      (lib.mkIf (config.hot-corners != null) [ config.hot-corners.rendered ])
    ];
  }))
]
