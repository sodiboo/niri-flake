{
  lib,
  kdl,
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
    make-decoration-options
    nullable
    float-or-int
    section
    shadow-descriptions
    list
    default-width
    ordered-section
    docs-only
    optional
    borderish
    decoration
    preset-width
    preset-height
    ;
in
ordered-section [
  {
    focus-ring = borderish {
      enable-by-default = true;
      name = "focus ring";
      window = "focused window";
      description = ''
        The focus ring is a decoration drawn ${fmt.em "around"} the last focused window on each monitor. It takes no space away from windows. If you have insufficient gaps, the focus ring can be drawn over adjacent windows, but it will never affect the layout of windows.

        The focused window of the currently focused monitor, i.e. the window that can receive keyboard input, will be drawn according to ${link-opt (subopts (subopts toplevel-options.layout).focus-ring).active}, and the last focused window on all other monitors will be drawn according to ${link-opt (subopts (subopts toplevel-options.layout).focus-ring).inactive}.

        If you have ${link-opt (subopts toplevel-options.layout).border} enabled, the focus ring will be drawn around (and under) the border.
      '';
    };

    border = borderish {
      enable-by-default = false;
      name = "border";
      window = "window";
      description = ''
        The border is a decoration drawn ${fmt.em "inside"} every window in the layout. It will take space away from windows. That is, if you have a border of 8px, then each window will be 8px smaller on each edge than if you had no border.

        The currently focused window, i.e. the window that can receive keyboard input, will be drawn according to ${link-opt (subopts (subopts toplevel-options.layout).border).active}, and all other windows will be drawn according to ${link-opt (subopts (subopts toplevel-options.layout).border).inactive}.

        If you have ${link-opt (subopts toplevel-options.layout).focus-ring} enabled, the border will be drawn inside (and over) the focus ring.
      '';
    };
  }
  {
    shadow = section {
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
  }
  {
    insert-hint =
      section' (
        { options, ... }:
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
            })
          ];
        }
      )
      // {
        description = ''
          The insert hint is a decoration drawn ${fmt.em "between"} windows during an interactive move operation. It is drawn in the gap where the window will be inserted when you release the window. It does not occupy any space in the gap, and the insert hint extends onto the edges of adjacent windows. When you release the moved window, the windows that are covered by the insert hint will be pushed aside to make room for the moved window.
        '';
      };
  }
  {
    "<decoration>" =
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
  }
  {
    background-color = nullable types.str // {
      description = ''
        The default background color that niri draws for workspaces. This is visible when you're not using any background tools like swaybg.
      '';
    };
  }
  {
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
  }
  {
    default-column-width = optional default-width { } // {
      description = ''
        The default width for new columns.

        When this is set to an empty attrset ${fmt.code "{}"}, windows will get to decide their initial width. This is not null, such that it can be distinguished from window rules that don't touch this

        See ${link-opt (subopts toplevel-options.layout).preset-column-widths} for more information.

        You can override this for specific windows using ${link-opt (subopts toplevel-options.window-rules).default-column-width}
      '';
    };
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

    tab-indicator = nullable (
      submodule (
        { options, ... }:
        {
          imports = make-ordered-options [
            {
              enable = optional types.bool true;
              hide-when-single-tab = optional types.bool false;
              place-within-column = optional types.bool false;
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

          ];
        }
      )
    );
  }
  {
    empty-workspace-above-first = optional types.bool false // {
      description = ''
        Normally, niri has a dynamic amount of workspaces, with one empty workspace at the end. The first workspace really is the first workspace, and you cannot go past it, but going past the last workspace puts you on the empty workspace.

        When this is enabled, there will be an empty workspace above the first workspace, and you can go past the first workspace to get to an empty workspace, just as in the other direction. This makes workspace navigation symmetric in all ways except indexing.
      '';
    };
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
  }
]
