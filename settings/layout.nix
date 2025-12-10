{
  lib,
  kdl,
  fragments,
  niri-flake-internal,
  toplevel-options,
}:
let
  appearance = import ./appearance {
    inherit
      lib
      kdl
      fragments
      niri-flake-internal
      toplevel-options
      ;
  };

  inherit (lib)
    types
    ;
  inherit (lib.types) enum;
  inherit (niri-flake-internal)
    fmt
    link-opt
    subopts
    section'
    make-ordered-options
    nullable
    float-or-int
    record
    optional
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
in
{
  sections = [
    {
      options.layout =
        rendered-ordered-section
          (
            appearance.layout
            ++ [
              {
                options.center-focused-column =
                  nullable (enum [
                    "never"
                    "always"
                    "on-overflow"
                  ])
                  // {
                    description = ''
                      When changing focus, niri can automatically center the focused column.

                      ${fmt.list [
                        "${fmt.code ''"never"''}: If the focused column doesn't fit, it will be aligned to the edges of the screen."
                        "${fmt.code ''"on-overflow"''}: if the focused column doesn't fit, it will be centered on the screen."
                        "${fmt.code ''"always"''}: the focused column will always be centered, even if it was already fully visible."
                      ]}
                    '';
                  };
                render = config: [
                  (lib.mkIf (config.center-focused-column != null) [
                    (kdl.leaf "center-focused-column" config.center-focused-column)
                  ])
                ];
              }
              {
                options.always-center-single-column = nullable types.bool // {
                  description = ''
                    This is like ${fmt.code ''center-focused-column = "always";''}, but only for workspaces with a single column. Changes nothing if ${fmt.code "center-focused-column"} is set to ${fmt.code ''"always"''}. Has no effect if more than one column is present.
                  '';
                };
                render = config: [
                  (lib.mkIf (config.always-center-single-column != null) [
                    (kdl.leaf "always-center-single-column" config.always-center-single-column)
                  ])
                ];
              }
              {
                options.empty-workspace-above-first = nullable types.bool // {
                  description = ''
                    Normally, niri has a dynamic amount of workspaces, with one empty workspace at the end. The first workspace really is the first workspace, and you cannot go past it, but going past the last workspace puts you on the empty workspace.

                    When this is enabled, there will be an empty workspace above the first workspace, and you can go past the first workspace to get to an empty workspace, just as in the other direction. This makes workspace navigation symmetric in all ways except indexing.
                  '';
                };
                render = config: [
                  (lib.mkIf (config.empty-workspace-above-first != null) [
                    (kdl.leaf "empty-workspace-above-first" config.empty-workspace-above-first)
                  ])
                ];
              }
              {
                options.gaps = nullable float-or-int // {
                  description = ''
                    The gap between windows in the layout, measured in logical pixels.
                  '';
                };
                render = config: [
                  (lib.mkIf (config.gaps != null) [
                    (kdl.leaf "gaps" config.gaps)
                  ])
                ];
              }
              {
                options = {
                  struts =
                    nullable (record {
                      left = optional float-or-int 0;
                      right = optional float-or-int 0;
                      top = optional float-or-int 0;
                      bottom = optional float-or-int 0;
                    })
                    // {
                      description = ''
                        The distances from the edges of the screen to the eges of the working area.

                        The top and bottom struts are absolute gaps from the edges of the screen. If you set a bottom strut of 64px and the scale is 2.0, then the output will have 128 physical pixels under the scrollable working area where it only shows the wallpaper.

                        Struts are computed in addition to layer-shell surfaces. If you have a waybar of 32px at the top, and you set a top strut of 16px, then you will have 48 logical pixels from the actual edge of the display to the top of the working area.

                        The left and right structs work in a similar way, except the padded space is not empty. The horizontal struts are used to constrain where focused windows are allowed to go. If you define a left strut of 64px and go to the first window in a workspace, that window will be aligned 64 logical pixels from the left edge of the output, rather than snapping to the actual edge of the screen. If another window exists to the left of this window, then you will see 64px of its right edge (if you have zero borders and gaps)
                      '';
                    };
                };
                render = config: [
                  (lib.mkIf (config.struts != null) [
                    (kdl.plain "struts" [
                      (kdl.leaf "left" config.struts.left)
                      (kdl.leaf "right" config.struts.right)
                      (kdl.leaf "top" config.struts.top)
                      (kdl.leaf "bottom" config.struts.bottom)
                    ])
                  ])
                ];
              }
            ]
          )
          (
            content:
            {
              config,
              ...
            }:
            {
              options.rendered = lib.mkOption {
                type = kdl.types.kdl-node;
                readOnly = true;
                internal = true;
                visible = false;
                apply = node: lib.mkIf (node.children != [ ]) node;
              };
              config.rendered = kdl.plain "layout" [ content ];
            }
          );
      render = config: config.layout.rendered;
    }
  ];
}
