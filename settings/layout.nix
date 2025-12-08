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
  inherit (lib.types) enum submodule;
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
    docs-only
    optional
    record'
    required
    link-niri-release
    shorthand-for
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

  # niri seems to have deprecated this way of defining colors; so we won't support it
  # color-array = mkOptionType {
  #   name = "color";
  #   description = "[red green blue alpha]";
  #   descriptionClass = "noun";
  #   check = v: isList v && length v == 4 && all isInt v;
  # };

  decoration =
    self:

    let
      css-color = fmt.masked-link {
        href = "https://developer.mozilla.org/en-US/docs/Web/CSS/color_value";
        content = fmt.code "<color>";
      };

      css-linear-gradient = fmt.masked-link {
        href = "https://developer.mozilla.org/en-US/docs/Web/CSS/gradient/linear-gradient";
        content = fmt.code "linear-gradient()";
      };

      css-color-interpolation-method = fmt.masked-link {
        href = "https://developer.mozilla.org/en-US/docs/Web/CSS/color-interpolation-method";
        content = fmt.code "<color-interpolation-method>";
      };

      csscolorparser-crate = fmt.masked-link {
        href = "https://crates.io/crates/csscolorparser";
        content = fmt.code "csscolorparser";
      };
    in
    types.attrTag {
      color = lib.mkOption {
        type = types.str;
        description = ''
          A solid color to use for the decoration.

          This is a CSS ${css-color} value, like ${fmt.code ''"rgb(255 0 0)"''}, ${fmt.code ''"#C0FFEE"''}, or ${fmt.code ''"sandybrown"''}.

          The specific crate that niri uses to parse this also supports some nonstandard color functions, like ${fmt.code "hwba()"}, ${fmt.code "hsv()"}, ${fmt.code "hsva()"}. See ${csscolorparser-crate} for details.
        '';
      };
      gradient = lib.mkOption {
        description = ''
          A linear gradient to use for the decoration.

          This is meant to approximate the CSS ${css-linear-gradient} function, but niri does not fully support all the same parameters. Only an angle in degrees is supported.
        '';
        type = record' "gradient" {
          from = required types.str // {
            description = ''
              The starting ${css-color} of the gradient.

              For more details, see ${link-opt (subopts self).color}.
            '';
          };
          to = required types.str // {
            description = ''
              The ending ${css-color} of the gradient.

              For more details, see ${link-opt (subopts self).color}.
            '';
          };
          angle = optional types.int 180 // {
            description = ''
              The angle of the gradient, in degrees, measured clockwise from a gradient that starts at the bottom and ends at the top.

              This is the same as the angle parameter in the CSS ${css-linear-gradient} function, except you can only express it in degrees.
            '';
          };
          in' =
            nullable (enum [
              "srgb"
              "srgb-linear"
              "oklab"
              "oklch shorter hue"
              "oklch longer hue"
              "oklch increasing hue"
              "oklch decreasing hue"
            ])
            // {
              description = ''
                The colorspace to interpolate the gradient in. This option is named ${fmt.code "in'"} because ${fmt.code "in"} is a reserved keyword in Nix.

                This is a subset of the ${css-color-interpolation-method} values in CSS.
              '';
            };
          relative-to =
            optional (enum [
              "window"
              "workspace-view"
            ]) "window"
            // {
              description = ''
                The rectangle that this gradient is contained within.

                If a gradient is ${fmt.code "relative-to"} the ${fmt.code ''"window"''}, then the gradient will start and stop at the window bounds. If you have many windows, then the gradients will have many starts and stops.

                ${fmt.img {
                  src = "/assets/relative-to-window.png";
                  alt = ''
                    four windows arranged in two columns; a big window to the left of three stacked windows.
                    a gradient is drawn from the bottom left corner of each window, which is yellow, transitioning to red at the top right corner of each window.
                    the three vertical windows look identical, with a yellow and red corner, and the other two corners are slightly different shades of orange.
                    the big window has a yellow and red corner, with the top left corner being a very red orange orange, and the bottom right corner being a very yellow orange.
                    the top edge of the top stacked window has a noticeable transition from a yellowish orange to completely red.
                  '';
                  title = ''behaviour of relative-to="window"'';
                }}

                If the gradient is instead ${fmt.code "relative-to"} the ${fmt.code ''"workspace-view"''}, then the gradient will start and stop at the bounds of your view. Windows decorations will take on the color values from just the part of the screen that they occupy

                ${fmt.img {
                  src = "/assets/relative-to-workspace-view.png";
                  alt = ''
                    four windows arranged in two columns; a big window to the left of three stacked windows.
                    a gradient is drawn from the bottom left corner of the workspace view, which is yellow, transitioning to red at the top right corner of the workspace view.
                    it looks like the gradient starts in the bottom left of the big window, and ends in the top right of the upper stacked window.
                    the bottom left corner of the top stacked window is a red orange color, and the bottom left corner of the middle stacked window is a more neutral orange color.
                    the bottom edge of the big window is almost entirely yellow, and the top edge of the top stacked window is almost entirely red.
                  '';
                  title = ''behaviour of relative-to="workspace-view"'';
                }}

                these beautiful images are sourced from the release notes for ${link-niri-release "v0.1.3"}
              '';
            };
        };
      };
    };

  make-decoration-options = options: variants: {
    options = builtins.mapAttrs (
      name:
      { description }:
      nullable (shorthand-for "decoration" (decoration (options.${name})))
      // {
        visible = "shallow";
        inherit description;
      }
    ) variants;
    render =
      config:
      builtins.map (name: [
        (lib.mkIf (config ? ${name}.color) [
          (kdl.leaf "${name}-color" config.${name}.color)
        ])
        (lib.mkIf (config ? ${name}.gradient) [
          (render-gradient "${name}-gradient" config.${name}.gradient)
        ])
      ]) (builtins.attrNames (variants));
  };

  render-gradient =
    name: cfg:
    kdl.leaf name (
      lib.concatMapAttrs (
        name: value:
        lib.optionalAttrs (value != null) {
          ${lib.removeSuffix "'" name} = value;
        }
      ) cfg
    );

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
      shadow-descriptions
      default-height
      default-width
      make-decoration-options
      ;
  };

  sections = [
    {
      options.layout =
        rendered-ordered-section
          [
            {
              options =
                let
                  make-borderish-option =
                    {
                      enable-by-default,
                      node-name,
                      name,
                      window,
                      description,
                    }:
                    lib.mkOption {
                      inherit description;
                      default = { };
                      type = lib.types.submodule (
                        { options, ... }:
                        {
                          imports =
                            make-rendered-ordered-options
                              [
                                {
                                  options.enable = optional types.bool enable-by-default // {
                                    description = ''
                                      Whether to enable the ${name}.
                                    '';
                                  };
                                  render = _: [ ];
                                }
                                {
                                  options.width = optional float-or-int 4 // {
                                    description = ''
                                      The width of the ${name} drawn around each ${window}.
                                    '';
                                  };
                                  render = config: (kdl.leaf "width" config.width);
                                }

                                (make-decoration-options options {
                                  urgent.description = ''
                                    The color of the ${name} for windows that are requesting attention.
                                  '';
                                  active.description = ''
                                    The color of the ${name} for the window that has keyboard focus.
                                  '';
                                  inactive.description = ''
                                    The color of the ${name} for windows that do not have keyboard focus.
                                  '';
                                })
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
                                  };
                                  config.rendered = kdl.plain node-name [
                                    (lib.mkIf (!config.enable) (kdl.flag "off"))
                                    (lib.mkIf (config.enable) [
                                      content
                                    ])
                                  ];
                                }
                              );
                        }
                      );
                    };
                in
                {
                  focus-ring = make-borderish-option {
                    enable-by-default = true;
                    node-name = "focus-ring";
                    name = "focus ring";
                    window = "focused window";
                    description = ''
                      The focus ring is a decoration drawn ${fmt.em "around"} the last focused window on each monitor. It takes no space away from windows. If you have insufficient gaps, the focus ring can be drawn over adjacent windows, but it will never affect the layout of windows.

                      The focused window of the currently focused monitor, i.e. the window that can receive keyboard input, will be drawn according to ${link-opt (subopts (subopts toplevel-options.layout).focus-ring).active}, and the last focused window on all other monitors will be drawn according to ${link-opt (subopts (subopts toplevel-options.layout).focus-ring).inactive}.

                      If you have ${link-opt (subopts toplevel-options.layout).border} enabled, the focus ring will be drawn around (and under) the border.
                    '';
                  };

                  border = make-borderish-option {
                    enable-by-default = false;
                    node-name = "border";
                    name = "border";
                    window = "window";
                    description = ''
                      The border is a decoration drawn ${fmt.em "inside"} every window in the layout. It will take space away from windows. That is, if you have a border of 8px, then each window will be 8px smaller on each edge than if you had no border.

                      The currently focused window, i.e. the window that can receive keyboard input, will be drawn according to ${link-opt (subopts (subopts toplevel-options.layout).border).active}, and all other windows will be drawn according to ${link-opt (subopts (subopts toplevel-options.layout).border).inactive}.

                      If you have ${link-opt (subopts toplevel-options.layout).focus-ring} enabled, the border will be drawn inside (and over) the focus ring.
                    '';
                  };
                };
              render = config: [
                config.focus-ring.rendered
                config.border.rendered
              ];
            }
            {
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
            }
            {
              options.insert-hint =
                section' (
                  { config, options, ... }:
                  {
                    imports = make-ordered-options [
                      {
                        enable = optional types.bool true // {
                          description = ''
                            Whether to enable the insert hint.
                          '';
                        };
                      }
                      (make-decoration-options options {
                        display.description = ''
                          The color of the insert hint.
                        '';
                      }).options
                    ];

                    options.rendered = lib.mkOption {
                      type = kdl.types.kdl-node;
                      readOnly = true;
                      internal = true;
                      visible = false;
                      apply = node: lib.mkIf (node.children != [ ]) node;
                    };
                    config.rendered = kdl.plain "insert-hint" [
                      (lib.mkIf (!config.enable) (kdl.flag "off"))
                      (lib.mkIf (config.enable) [
                        (lib.mkIf (config ? display.color) [
                          (kdl.leaf "color" config.display.color)
                        ])
                        (lib.mkIf (config ? display.gradient) [
                          (render-gradient "gradient" config.display.gradient)
                        ])
                      ])
                    ];
                  }
                )
                // {
                  description = ''
                    The insert hint is a decoration drawn ${fmt.em "between"} windows during an interactive move operation. It is drawn in the gap where the window will be inserted when you release the window. It does not occupy any space in the gap, and the insert hint extends onto the edges of adjacent windows. When you release the moved window, the windows that are covered by the insert hint will be pushed aside to make room for the moved window.
                  '';
                };
              render = config: config.insert-hint.rendered;
            }
            {
              options.tab-indicator = nullable (
                submodule (
                  { options, ... }:
                  {
                    imports =
                      make-rendered-ordered-options
                        [
                          {
                            options.enable = optional types.bool true;
                            render = _: [ ];
                          }
                          {
                            options.hide-when-single-tab = optional types.bool false;
                            render = config: [
                              (lib.mkIf (config.hide-when-single-tab) [
                                (kdl.flag "hide-when-single-tab")
                              ])
                            ];
                          }
                          {
                            options.place-within-column = optional types.bool false;
                            render = config: [
                              (lib.mkIf (config.place-within-column) [
                                (kdl.flag "place-within-column")
                              ])
                            ];
                          }
                          {
                            options = {
                              gap = optional float-or-int 5.0;
                              width = optional float-or-int 4.0;
                              length.total-proportion = optional types.float 0.5;

                              position = optional (enum [
                                "left"
                                "right"
                                "top"
                                "bottom"
                              ]) "left";
                              gaps-between-tabs = optional float-or-int 0.0;
                              corner-radius = optional float-or-int 0.0;
                            };

                            render = config: [
                              (kdl.leaf "gap" config.gap)
                              (kdl.leaf "width" config.width)
                              (kdl.leaf "length" config.length)
                              (kdl.leaf "position" config.position)
                              (kdl.leaf "gaps-between-tabs" config.gaps-between-tabs)
                              (kdl.leaf "corner-radius" config.corner-radius)
                            ];
                          }
                          (make-decoration-options options {
                            urgent.description = ''
                              The color of the tab indicator for windows that are requesting attention.
                            '';
                            active.description = ''
                              The color of the tab indicator for the window that has keyboard focus.
                            '';
                            inactive.description = ''
                              The color of the tab indicator for windows that do not have keyboard focus.
                            '';
                          })
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
                            };
                            config.rendered = kdl.plain "tab-indicator" [
                              (lib.mkIf (!config.enable) (kdl.flag "off"))
                              (lib.mkIf (config.enable) [ content ])
                            ];
                          }
                        );
                  }
                )
              );
              render = config: [
                (lib.mkIf (config.tab-indicator != null) [
                  config.tab-indicator.rendered
                ])
              ];
            }
            {
              options."<decoration>" =
                let
                  self = docs-only (decoration (self // { loc = [ "<decoration>" ]; })) // {
                    override-loc = lib.const [ "<decoration>" ];
                    description = ''
                      A decoration is drawn around a surface, adding additional elements that are not necessarily part of an application, but are part of what we think of as a "window".

                      This type specifically represents decorations drawn by niri: that is, ${link-opt (subopts toplevel-options.layout).focus-ring} and/or ${link-opt (subopts toplevel-options.layout).border}.
                    '';
                  };
                in
                self;
              render = _: [ ];
            }
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
