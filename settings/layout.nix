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
    section
    list
    optional
    ;

  preset-size =
    dimension: object:
    types.attrTag {
      fixed = lib.mkOption {
        type = types.int;
        description = ''
          The ${dimension} of the ${object} in logical pixels
        '';
      };
      proportion = lib.mkOption {
        type = types.float;
        description = ''
          The ${dimension} of the ${object} as a proportion of the screen's ${dimension}
        '';
      };
    };

  preset-width = preset-size "width" "column";
  preset-height = preset-size "height" "window";

  emptyOr =
    elemType:
    lib.mkOptionType {
      name = "emptyOr";
      description =
        if
          builtins.elem elemType.descriptionClass [
            "noun"
            "conjunction"
          ]
        then
          "{} or ${elemType.description}"
        else
          "{} or (${elemType.description})";
      descriptionClass = "conjunction";
      check = v: v == { } || elemType.check v;
      nestedTypes.elemType = elemType;
      merge =
        loc: defs: if builtins.all (def: def.value == { }) defs then { } else elemType.merge loc defs;

      inherit (elemType) getSubOptions;
    };

  default-width = emptyOr preset-width;
  default-height = emptyOr preset-height;

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
  fragments = {
    inherit
      default-height
      default-width
      ;
  };

  sections = [
    {
      options.layout =
        rendered-ordered-section
          (
            appearance.layout
            ++ [
              {
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
              }
              {
                options = {
                  preset-column-widths = list preset-width // {
                    description = ''
                      The widths that ${fmt.code "switch-preset-column-width"} will cycle through.

                      Each width can either be a fixed width in logical pixels, or a proportion of the screen's width.

                      Example:

                      ${fmt.nix-code-block ''
                        {
                          ${(subopts toplevel-options.layout).preset-column-widths} = [
                            { proportion = 1. / 3.; }
                            { proportion = 1. / 2.; }
                            { proportion = 2. / 3.; }

                            # { fixed = 1920; }
                          ];
                        }
                      ''}
                    '';
                  };
                  preset-window-heights = list preset-height // {
                    description = ''
                      The heights that ${fmt.code "switch-preset-window-height"} will cycle through.

                      Each height can either be a fixed height in logical pixels, or a proportion of the screen's height.

                      Example:

                      ${fmt.nix-code-block ''
                        {
                          ${(subopts toplevel-options.layout).preset-window-heights} = [
                            { proportion = 1. / 3.; }
                            { proportion = 1. / 2.; }
                            { proportion = 2. / 3.; }

                            # { fixed = 1080; }
                          ];
                        }
                      ''}
                    '';
                  };
                };

                render = config: [
                  (lib.mkIf (config.preset-column-widths != [ ]) [
                    (kdl.plain "preset-column-widths" [
                      (map (lib.mapAttrsToList kdl.leaf) config.preset-column-widths)
                    ])
                  ])
                  (lib.mkIf (config.preset-window-heights != [ ]) [
                    (kdl.plain "preset-window-heights" [
                      (map (lib.mapAttrsToList kdl.leaf) config.preset-window-heights)
                    ])
                  ])
                ];
              }
              {
                options.default-column-width = optional default-width { } // {
                  description = ''
                    The default width for new columns.

                    When this is set to an empty attrset ${fmt.code "{}"}, windows will get to decide their initial width. This is not null, such that it can be distinguished from window rules that don't touch this

                    See ${link-opt (subopts toplevel-options.layout).preset-column-widths} for more information.

                    You can override this for specific windows using ${link-opt (subopts toplevel-options.window-rules).default-column-width}
                  '';
                };
                render = config: [
                  (kdl.plain "default-column-width" [
                    (lib.mapAttrsToList kdl.leaf config.default-column-width)
                  ])
                ];
              }
              {
                options = {
                  center-focused-column =
                    optional (enum [
                      "never"
                      "always"
                      "on-overflow"
                    ]) "never"
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
                  always-center-single-column = optional types.bool false // {
                    description = ''
                      This is like ${fmt.code ''center-focused-column = "always";''}, but only for workspaces with a single column. Changes nothing if ${fmt.code "center-focused-column"} is set to ${fmt.code ''"always"''}. Has no effect if more than one column is present.
                    '';
                  };
                  default-column-display =
                    optional (enum [
                      "normal"
                      "tabbed"
                    ]) "normal"
                    // {
                      description = ''
                        How windows in columns should be displayed by default.

                        ${fmt.list [
                          "${fmt.code ''"normal"''}: Windows are arranged vertically, spread across the working area height."
                          "${fmt.code ''"tabbed"''}: Windows are arranged in tabs, with only the focused window visible, taking up the full height of the working area."
                        ]}

                        Note that you can override this for a given column at any time. Every column remembers its own display mode, independent from this setting. This setting controls the default value when a column is ${fmt.em "created"}.

                        Also, since a newly created column always contains a single window, you can override this default value with ${link-opt (subopts toplevel-options.window-rules).default-column-display}.
                      '';
                    };
                };
                render = config: [
                  (kdl.leaf "center-focused-column" config.center-focused-column)
                  (lib.mkIf (config.always-center-single-column) [
                    (kdl.flag "always-center-single-column")
                  ])
                  (lib.mkIf (config.default-column-display != "normal") [
                    (kdl.leaf "default-column-display" config.default-column-display)
                  ])
                ];
              }
              {
                options.empty-workspace-above-first = optional types.bool false // {
                  description = ''
                    Normally, niri has a dynamic amount of workspaces, with one empty workspace at the end. The first workspace really is the first workspace, and you cannot go past it, but going past the last workspace puts you on the empty workspace.

                    When this is enabled, there will be an empty workspace above the first workspace, and you can go past the first workspace to get to an empty workspace, just as in the other direction. This makes workspace navigation symmetric in all ways except indexing.
                  '';
                };
                render = config: [
                  (lib.mkIf (config.empty-workspace-above-first) [
                    (kdl.flag "empty-workspace-above-first")
                  ])
                ];

              }
              {
                options = {
                  gaps = optional float-or-int 16 // {
                    description = ''
                      The gap between windows in the layout, measured in logical pixels.
                    '';
                  };
                  struts =
                    section {
                      left = optional float-or-int 0;
                      right = optional float-or-int 0;
                      top = optional float-or-int 0;
                      bottom = optional float-or-int 0;
                    }
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
                  (kdl.leaf "gaps" config.gaps)
                  (kdl.plain "struts" [
                    (kdl.leaf "left" config.struts.left)
                    (kdl.leaf "right" config.struts.right)
                    (kdl.leaf "top" config.struts.top)
                    (kdl.leaf "bottom" config.struts.bottom)
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
              };
              config.rendered = kdl.plain "layout" [ content ];
            }
          );
      render = config: config.layout.rendered;
    }
  ];
}
