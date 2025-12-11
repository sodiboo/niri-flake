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
    ;

  make-rendered-ordered-options = sections: final: [
    (
      { config, ... }:
      {
        imports = make-ordered-options (map (s: s.options) sections) ++ [
          (final (map (s: s.render config) sections))
        ];
      }
    )
  ];

  rendered-ordered-section = sections: final: section' (make-rendered-ordered-options sections final);

  css-box-shadow =
    prop:
    fmt.masked-link {
      href = "https://developer.mozilla.org/en-US/docs/Web/CSS/box-shadow#syntax";
      content = "CSS box-shadow ${prop}";
    };

  make-shadow-option =
    node-name: extra-options:
    rendered-ordered-section
      (
        [
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
        ]
        ++ extra-options
      )
      (
        content:
        { config, ... }:
        {
          options.rendered = lib.mkOption {
            type = kdl.types.kdl-node;
            readOnly = true;
            internal = true;
            visible = false;
            apply = node: lib.mkIf (node.children != [ ]) node;
          };
          config.rendered = kdl.plain node-name [ content ];
        }
      );

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
