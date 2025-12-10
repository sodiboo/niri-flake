{
  lib,
  kdl,
  fragments,
  niri-flake-internal,
  toplevel-options,
}:
let
  inherit (lib)
    types
    ;
  inherit (niri-flake-internal)
    nullable
    float-or-int
    optional
    record
    make-ordered-options
    section'
    ;

  inherit (fragments) shadow-descriptions;

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
in
{
  sections = [
    {
      options.overview =
        rendered-ordered-section
          [
            {
              options.zoom = nullable float-or-int // {
                description = ''
                  Control how much the workspaces zoom out in the overview. zoom ranges from 0 to 0.75 where lower values make everything smaller.
                '';
              };
              render = config: [
                (lib.mkIf (config.zoom != null) [
                  (kdl.leaf "zoom" config.zoom)
                ])
              ];
            }
            {
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
            }
            {
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
              config.rendered = kdl.plain "overview" [
                content
              ];
            }
          );

      render = config: config.overview.rendered;
    }
  ];
}
