{
  lib,
  kdl,
  hierarchies,
  niri-flake-internal,
  toplevel-options,
  ...
}:

let
  inherit (lib) types;

  inherit (niri-flake-internal)
    fmt
    optional
    float-or-int
    subopts
    nullable
    required
    record
    record'
    docs-only
    shorthand-for
    ;

  inherit (hierarchies) layout-options;

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

              For more details, see ${fmt.link-opt (subopts self).color}.
            '';
          };
          to = required types.str // {
            description = ''
              The ending ${css-color} of the gradient.

              For more details, see ${fmt.link-opt (subopts self).color}.
            '';
          };
          angle = optional types.int 180 // {
            description = ''
              The angle of the gradient, in degrees, measured clockwise from a gradient that starts at the bottom and ends at the top.

              This is the same as the angle parameter in the CSS ${css-linear-gradient} function, except you can only express it in degrees.
            '';
          };
          in' =
            nullable (
              lib.types.enum [
                "srgb"
                "srgb-linear"
                "oklab"
                "oklch shorter hue"
                "oklch longer hue"
                "oklch increasing hue"
                "oklch decreasing hue"
              ]
            )
            // {
              description = ''
                The colorspace to interpolate the gradient in. This option is named ${fmt.code "in'"} because ${fmt.code "in"} is a reserved keyword in Nix.

                This is a subset of the ${css-color-interpolation-method} values in CSS.
              '';
            };
          relative-to =
            optional (lib.types.enum [
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

                these beautiful images are sourced from the release notes for ${fmt.link-niri-release "v0.1.3"}
              '';
            };
        };
      };
    };

  make-decoration-option =
    ctx: name:
    {
      description,
      color-node ? "${name}-color",
      gradient-node ? "${name}-gradient",
    }:
    {
      options.${name} = ctx.nullable name {
        type = (shorthand-for "decoration" (decoration (ctx.options.${name})));
        visible = "shallow";
        inherit description;
      };
      render = config: [
        (lib.mkIf (config ? ${name}.color) [
          (kdl.leaf color-node config.${name}.color)
        ])
        (lib.mkIf (config ? ${name}.gradient) [
          (render-gradient gradient-node config.${name}.gradient)
        ])
      ];
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

  borderish =
    {
      node-name,
      name,
      window,
      description,
    }:
    layout-options.window-level (ctx: {
      options.${node-name} =
        ctx.rendered-section node-name
          {
            partial = true;
            description = description ctx.options;
          }
          (ctx: [
            {
              options.enable = ctx.nullable "enable" {
                type = types.bool;
                description = ''
                  Whether to enable the ${name}.
                '';
              };
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
              options.width = ctx.nullable "width" {
                type = float-or-int;
                description = ''
                  The width of the ${name} drawn around each ${window}.
                '';
              };
              render = config: [
                (lib.mkIf (config.width != null) [
                  (kdl.leaf "width" config.width)
                ])
              ];
            }
            (make-decoration-option ctx "urgent" {
              description = ''
                The color of the ${name} for windows that are requesting attention.
              '';
            })
            (make-decoration-option ctx "active" {
              description = ''
                The color of the ${name} for the window that has keyboard focus.
              '';
            })
            (make-decoration-option ctx "inactive" {
              description = ''
                The color of the ${name} for windows that do not have keyboard focus.
              '';
            })
          ]);
      render = config: config.${node-name}.rendered;
    });
in
[
  (borderish {
    node-name = "border";
    name = "border";
    window = "window";
    description = layout: ''
      The border is a decoration drawn ${fmt.em "inside"} every window in the layout. It will take space away from windows. That is, if you have a border of 8px, then each window will be 8px smaller on each edge than if you had no border.

      The currently focused window (i.e. the window that can receive keyboard input) will be drawn according to ${
        fmt.link-opt' (subopts layout.border).active [
          "border"
          "active"
        ]
      }, and all other windows will be drawn according to ${
        fmt.link-opt' (subopts layout.border).inactive [
          "border"
          "inactive"
        ]
      }.

      If you have the ${
        fmt.link-opt' layout.focus-ring [ "focus-ring" ]
      } enabled, the border will be drawn inside (and over) the focus ring.
    '';
  })
  (borderish {
    node-name = "focus-ring";
    name = "focus ring";
    window = "focused window";
    description = layout: ''
      The focus ring is a decoration drawn ${fmt.em "around"} the last focused window on each workspace. It takes no space away from windows. If you have insufficient gaps, the focus ring can be drawn over adjacent windows, but it will never affect the layout of windows.

      The focused window of the currently focused workspace (i.e. the window that can receive keyboard input) will be drawn according to ${
        fmt.link-opt' (subopts layout.focus-ring).active [
          "focus-ring"
          "active"
        ]
      }, and the last focused window on all other workspaces will be drawn according to ${
        fmt.link-opt' (subopts layout.focus-ring).inactive [
          "focus-ring"
          "inactive"
        ]
      }.

      If you have the ${
        fmt.link-opt' layout.border [ "border" ]
      } enabled, the focus ring will be drawn around (and under) the border.
    '';
  })
  (layout-options.output-level (ctx: {
    options.insert-hint =
      ctx.rendered-section "insert-hint"
        {
          partial = true;
          description = ''
            The insert hint is a decoration drawn ${fmt.em "between"} windows during an interactive move operation. It is drawn in the gap where the window will be inserted when you release the window. It does not occupy any space in the gap, and the insert hint extends onto the edges of adjacent windows. When you release the moved window, the windows that are covered by the insert hint will be pushed aside to make room for the moved window.

            Note that the insert hint is also shown in the overview when dragging a window in the gaps between workspaces, to indicate that releasing it will create a new workspace with that window. As such, insert hints are actually an output-level concept, and so there is no workspace-level configuration.
          '';
        }
        (ctx: [
          {
            options.enable = ctx.nullable "enable" {
              type = types.bool;
              description = ''
                Whether to enable the insert hint.
              '';
            };
            render = config: [
              (lib.mkIf (config.enable == true) [
                (kdl.flag "on")
              ])
              (lib.mkIf (config.enable == false) [
                (kdl.flag "off")
              ])
            ];
          }
          (make-decoration-option ctx "display" {
            description = ''
              The color of the insert hint.
            '';
            color-node = "color";
            gradient-node = "gradient";
          })
        ]);
    render = config: config.insert-hint.rendered;
  }))
  (layout-options.window-level (ctx: {
    options.tab-indicator = ctx.rendered-section "tab-indicator" { partial = true; } (ctx: [
      (ctx.workspace-level (ctx: [
        {
          options.enable = ctx.nullable "enable" { type = types.bool; };
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
          options.hide-when-single-tab = ctx.nullable "hide-when-single-tab" { type = types.bool; };
          render = config: [
            (lib.mkIf (config.hide-when-single-tab != null) [
              (kdl.leaf "hide-when-single-tab" config.hide-when-single-tab)
            ])
          ];
        }
        {
          options.place-within-column = ctx.nullable "place-within-column" { type = types.bool; };
          render = config: [
            (lib.mkIf (config.place-within-column != null) [
              (kdl.leaf "place-within-column" config.place-within-column)
            ])
          ];
        }
        {
          options.gap = ctx.nullable "gap" { type = float-or-int; };
          render = config: [
            (lib.mkIf (config.gap != null) [
              (kdl.leaf "gap" config.gap)
            ])
          ];
        }
        {
          options.width = ctx.nullable "width" { type = float-or-int; };
          render = config: [
            (lib.mkIf (config.width != null) [
              (kdl.leaf "width" config.width)
            ])
          ];
        }
        {
          options.length = ctx.nullable "length" {
            type = record {
              total-proportion = required types.float;
            };
          };
          render = config: [
            (lib.mkIf (config.length != null) [
              (kdl.leaf "length" config.length)
            ])
          ];
        }
        {
          options.position = ctx.nullable "position" {
            type = lib.types.enum [
              "left"
              "right"
              "top"
              "bottom"
            ];
          };
          render = config: [
            (lib.mkIf (config.position != null) [
              (kdl.leaf "position" config.position)
            ])
          ];
        }
        {
          options.gaps-between-tabs = ctx.nullable "gaps-between-tabs" { type = float-or-int; };
          render = config: [
            (lib.mkIf (config.gaps-between-tabs != null) [
              (kdl.leaf "gaps-between-tabs" config.gaps-between-tabs)
            ])
          ];
        }
        {
          options.corner-radius = ctx.nullable "corner-radius" { type = float-or-int; };
          render = config: [
            (lib.mkIf (config.corner-radius != null) [
              (kdl.leaf "corner-radius" config.corner-radius)
            ])
          ];
        }
      ]))
      (make-decoration-option ctx "urgent" {
        description = ''
          The color of the tab indicator for windows that are requesting attention.
        '';
      })
      (make-decoration-option ctx "active" {
        description = ''
          The color of the tab indicator for the window that has keyboard focus.
        '';
      })
      (make-decoration-option ctx "inactive" {
        description = ''
          The color of the tab indicator for windows that do not have keyboard focus.
        '';
      })
    ]);
    render = config: config.tab-indicator.rendered;
  }))
  {
    global-layout = {
      options."<decoration>" =
        let
          self = docs-only (decoration (self // { loc = [ "<decoration>" ]; })) // {
            override-loc = lib.const [ "<decoration>" ];
            description = ''
              A decoration is drawn around a surface, adding additional elements that are not necessarily part of an application, but are part of what we think of as a "window".

              This type specifically represents decorations drawn by niri: that is, ${fmt.link-opt (subopts toplevel-options.layout).focus-ring} and/or ${fmt.link-opt (subopts toplevel-options.layout).border}.
            '';
          };
        in
        self;
      render = _: [ ];
    };
  }
]
