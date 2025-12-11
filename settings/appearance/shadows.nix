{
  lib,
  kdl,
  niri-flake-internal,
  toplevel-options,
  ...
}:

let
  inherit (lib) types;

  inherit (niri-flake-internal)
    fmt
    make-rendered-section
    float-or-int
    nullable
    record
    required
    ;

  css-box-shadow =
    prop:
    fmt.masked-link {
      href = "https://developer.mozilla.org/en-US/docs/Web/CSS/box-shadow#syntax";
      content = "CSS box-shadow ${prop}";
    };

  make-shadow-option =
    node-name: extra-options:
    make-rendered-section node-name { partial = true; } [
      {
        options.enable = nullable types.bool;
        render = config: [
          (lib.mkIf (config.enable == true) [
            (kdl.flag "on")
          ])
          (lib.mkIf (config.enable == false) [
            (kdl.flag "off")
          ])
        ];
      }
      {
        options.offset =
          nullable (record {
            x = required float-or-int;
            y = required float-or-int;
          })
          // {
            description = ''
              The offset of the shadow from the window, measured in logical pixels.

              This behaves like a ${css-box-shadow "offset"}
            '';
          };
        render = config: [
          (lib.mkIf (config.offset != null) [
            (kdl.leaf "offset" config.offset)
          ])
        ];
      }
      {
        options.softness = nullable float-or-int // {
          description = ''
            The softness/size of the shadow, measured in logical pixels.

            This behaves like a ${css-box-shadow "blur radius"}
          '';
        };
        render = config: [
          (lib.mkIf (config.softness != null) [
            (kdl.leaf "softness" config.softness)
          ])
        ];
      }
      {
        options.spread = nullable float-or-int // {
          description = ''
            The spread of the shadow, measured in logical pixels.

            This behaves like a ${css-box-shadow "spread radius"}
          '';
        };
        render = config: [
          (lib.mkIf (config.spread != null) [
            (kdl.leaf "spread" config.spread)
          ])
        ];
      }
      {
        options.draw-behind-window = nullable types.bool;
        render = config: [
          (lib.mkIf (config.draw-behind-window != null) [
            (kdl.leaf "draw-behind-window" config.draw-behind-window)
          ])
        ];
      }
      {
        options.color = nullable types.str;
        render = config: [
          (lib.mkIf (config.color != null) [
            (kdl.leaf "color" config.color)
          ])
        ];
      }
      extra-options
    ];

  surface-shadow = {
    options.shadow = make-shadow-option "shadow" [
      {
        options.inactive-color = nullable types.str;
        render = config: [
          (lib.mkIf (config.inactive-color != null) [
            (kdl.leaf "inactive-color" config.inactive-color)
          ])
        ];
      }
    ];
    render = config: config.shadow.rendered;
  };
in
[
  {
    layout = surface-shadow;
    window-rule = surface-shadow;
    layer-rule = surface-shadow;
    overview = {
      options.workspace-shadow = make-shadow-option "workspace-shadow" [ ];
      render = config: config.workspace-shadow.rendered;
    };
  }
]
