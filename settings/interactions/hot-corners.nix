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
    make-ordered-options
    optional
    float-or-int
    nullable
    section'
    section
    record
    required
    link-opt
    subopts
    ;
in
[
  (
    let
      make-hot-corners =
        {
          description,
        }:
        {
          options.hot-corners = lib.mkOption {
            inherit description;
            default = null;
            type = lib.types.nullOr (
              lib.types.submodule (
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
              )
            );
          };
          render = config: [
            (lib.mkIf (config.hot-corners != null) [ config.hot-corners.rendered ])
          ];
        };
    in
    {
      gesture = make-hot-corners {
        description = ''
          Hot corners allow you to put your mouse in the corner of an output to toggle the overview. This interaction also works while drag-and-dropping.

          By default, the top-left corner is the only hot corner. You can use this option to explicitly set which hot corners you want.

          Individual hot corners cannot be enabled/disabled separately. This option configures all four hot corners at once.

          You can configure different hot corners for each output with ${link-opt (subopts toplevel-options.outputs).hot-corners}
        '';
      };
      output = make-hot-corners {
        description = ''
          Hot corners allow you to put your mouse in the corner of an output to toggle the overview. This interaction also works while drag-and-dropping.

          By default, hot corner configuration is inherited from ${link-opt (subopts toplevel-options.gestures).hot-corners}. You can use this option to explicitly set which hot corners you want to use on this output.

          Individual hot corners cannot be enabled/disabled separately. This option configures all four hot corners at once.
        '';
      };
    }
  )
]
