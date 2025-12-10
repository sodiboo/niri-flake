{
  lib,
  kdl,
  fragments,
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

  shadow-descriptions =
    let
      css-box-shadow =
        prop:
        fmt.masked-link {
          href = "https://developer.mozilla.org/en-US/docs/Web/CSS/box-shadow#syntax";
          content = "CSS box-shadow ${prop}";
        };
    in
    {
      offset = ''
        The offset of the shadow from the window, measured in logical pixels.

        This behaves like a ${css-box-shadow "offset"}
      '';

      softness = ''
        The softness/size of the shadow, measured in logical pixels.

        This behaves like a ${css-box-shadow "blur radius"}
      '';

      spread = ''
        The spread of the shadow, measured in logical pixels.

        This behaves like a ${css-box-shadow "spread radius"}
      '';
    };

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

  surface-rule = {
    options.shadow =
      rendered-ordered-section
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
            options = {
              offset =
                nullable (record {
                  x = required float-or-int;
                  y = required float-or-int;
                })
                // {
                  description = shadow-descriptions.offset;
                };

              softness = nullable float-or-int // {
                description = shadow-descriptions.softness;
              };

              spread = nullable float-or-int // {
                description = shadow-descriptions.spread;
              };
            };

            render = config: [
              (lib.mkIf (config.offset != null) [
                (kdl.leaf "offset" config.offset)
              ])
              (lib.mkIf (config.softness != null) [
                (kdl.leaf "softness" config.softness)
              ])
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
            options = {
              color = nullable types.str;
              inactive-color = nullable types.str;
            };
            render = config: [
              (lib.mkIf (config.color != null) [
                (kdl.leaf "color" config.color)
              ])
              (lib.mkIf (config.inactive-color != null) [
                (kdl.leaf "inactive-color" config.inactive-color)
              ])
            ];
          }
        ]
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
            config.rendered = kdl.plain "shadow" [ content ];
          }
        );
    render = config: config.shadow.rendered;
  };
in
[
  {
    layout = {
      options.shadow = section {
        enable = optional types.bool false;
        offset =
          section {
            x = optional float-or-int 0.0;
            y = optional float-or-int 5.0;
          }
          // {
            description = shadow-descriptions.offset;
          };

        softness = optional float-or-int 30.0 // {
          description = shadow-descriptions.softness;
        };

        spread = optional float-or-int 5.0 // {
          description = shadow-descriptions.spread;
        };

        draw-behind-window = optional types.bool false;

        # 0x70 is 43.75% so let's use hex notation lol
        color = optional types.str "#00000070";

        inactive-color = nullable types.str;
      };

      render = config: [
        (lib.mkIf (config.shadow.enable) [
          (kdl.plain "shadow" [
            (kdl.flag "on")

            (kdl.leaf "offset" config.shadow.offset)
            (kdl.leaf "softness" config.shadow.softness)
            (kdl.leaf "spread" config.shadow.spread)

            (kdl.leaf "draw-behind-window" config.shadow.draw-behind-window)
            (kdl.leaf "color" config.shadow.color)
            (lib.mkIf (config.shadow.inactive-color != null) [
              (kdl.leaf "inactive-color" config.shadow.inactive-color)
            ])
          ])
        ])
      ];
    };
    window-rule = surface-rule;
    layer-rule = surface-rule;
    overview = {
      options.workspace-shadow =
        rendered-ordered-section
          ([
            {
              options.enable = optional types.bool true;
              render = _: [ ];
            }
            {
              options = {
                offset =
                  nullable (record {
                    x = optional float-or-int 0.0;
                    y = optional float-or-int 5.0;
                  })
                  // {
                    description = shadow-descriptions.offset;
                  };

                softness = nullable float-or-int // {
                  description = shadow-descriptions.softness;
                };

                spread = nullable float-or-int // {
                  description = shadow-descriptions.spread;
                };
              };

              render = config: [
                (lib.mkIf (config.offset != null) [
                  (kdl.leaf "offset" config.offset)
                ])
                (lib.mkIf (config.softness != null) [
                  (kdl.leaf "softness" config.softness)
                ])
                (lib.mkIf (config.spread != null) [
                  (kdl.leaf "spread" config.spread)
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
          ])
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
              config.rendered = kdl.plain "workspace-shadow" [
                (lib.mkIf (!config.enable) (kdl.flag "off"))
                (lib.mkIf (config.enable) [ content ])
              ];
            }
          );
      render = config: config.workspace-shadow.rendered;
    };
  }
]
