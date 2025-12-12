{
  lib,
  kdl,
  appearance,
  hierarchies,
  niri-flake-internal,
  toplevel-options,
  ...
}:

let
  inherit (lib) types;

  inherit (niri-flake-internal)
    fmt
    link-opt
    link-opt-masked
    subopts
    nullable
    optional
    record
    float-or-int
    ;

  inherit (hierarchies) layout-definition layout-options;

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
in
[
  (layout-definition (ctx: {
    options.layout = ctx.rendered-section "layout" { partial = true; } (
      ctx:
      ctx.contextual {
        global = appearance.global-layout;
        output = appearance.output-layout;
        workspace = appearance.workspace-layout;
      }
    );
    render = config: config.layout.rendered;
  }))
  (layout-options.workspace-level (ctx: {
    options.gaps = ctx.nullable "gaps" {
      type = float-or-int;
      description = ''
        The gap between windows in the layout, measured in logical pixels.
      '';
    };
    render = config: [
      (lib.mkIf (config.gaps != null) [
        (kdl.leaf "gaps" config.gaps)
      ])
    ];
  }))
  (layout-options.workspace-level (ctx: {
    options.struts = ctx.nullable "struts" {
      description = ''
        The distances from the edges of the workspace to the edges of the working area.

        The top and bottom struts are absolute gaps from the edges of the workspace. If you set a bottom strut of 64px and the scale is 2.0, then the workspace will have 128 physical pixels under the scrollable working area where it only shows the background.

        Struts are computed in addition to layer-shell surfaces. If you have a waybar of 32px at the top, and you set a top strut of 16px, then you will have 48 logical pixels from the actual edge of the display to the top of the working area.

        The left and right structs work in a similar way, except the padded space is not empty. The horizontal struts are used to constrain where focused windows are allowed to go. If you define a left strut of 64px and go to the first window in a workspace, that window will be aligned 64 logical pixels from the left edge of the output, rather than snapping to the actual edge of the screen. If another window exists to the left of this window, then you will see 64px of its right edge (if you have zero ${link-opt-masked ctx.options.border "borders"} and ${link-opt-masked ctx.options.gaps "gaps"})

        Note that individual struts cannot be modified separately. This option configures all four struts at once.
      '';

      type = record {
        left = optional float-or-int 0;
        right = optional float-or-int 0;
        top = optional float-or-int 0;
        bottom = optional float-or-int 0;
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
  }))
  (layout-options.output-level (ctx: {
    options.empty-workspace-above-first = ctx.nullable "empty-workspace-above-first" {
      type = types.bool;
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
  }))
  (layout-options.workspace-level (ctx: {
    options.preset-column-widths = ctx.nullable "preset-column-widths" {
      type = types.nonEmptyListOf preset-width;
      description = ''
        The widths that ${fmt.code "switch-preset-column-width"} will cycle through.

        Each width can either be a fixed width in logical pixels, or a proportion of the screen's width.

        Example:

        ${fmt.nix-code-block ''
          {
            ${ctx.options.preset-column-widths} = [
              { proportion = 1. / 3.; }
              { proportion = 1. / 2.; }
              { proportion = 2. / 3.; }

              { fixed = 1920; }
            ];
          }
        ''}
      '';
    };

    render = config: [
      (lib.mkIf (config.preset-column-widths != null) [
        (kdl.plain "preset-column-widths" [
          (map (lib.mapAttrsToList kdl.leaf) config.preset-column-widths)
        ])
      ])
    ];
  }))
  (layout-options.workspace-level (ctx: {
    options.preset-window-heights = ctx.nullable "preset-window-heights" {
      type = types.nonEmptyListOf preset-height;
      description = ''
        The heights that ${fmt.code "switch-preset-window-height"} will cycle through.

        Each height can either be a fixed height in logical pixels, or a proportion of the screen's height.

        Example:

        ${fmt.nix-code-block ''
          {
            ${ctx.options.preset-window-heights} = [
              { proportion = 1. / 3.; }
              { proportion = 1. / 2.; }
              { proportion = 2. / 3.; }

              { fixed = 1080; }
            ];
          }
        ''}
      '';
    };
    render = config: [
      (lib.mkIf (config.preset-window-heights != null) [
        (kdl.plain "preset-window-heights" [
          (map (lib.mapAttrsToList kdl.leaf) config.preset-window-heights)
        ])
      ])
    ];
  }))
  (layout-options.window-level (ctx: {
    options.default-column-width = ctx.nullable "default-column-width" {
      type = default-width;
      description = ''
        The default width for new columns with a freshly opened window.

        When this is set to an empty attrset ${fmt.code "{}"}, the window will get to decide its initial width. This is effectively "unsetting" the default column width. This is distinct from a null value, which represents taht this option is not set at this level, and its value should be inherited from elsewhere.

        A newly created column always contains exactly one window. As such, the window rule variant of this option can match on properties of that singular window.

        See ${link-opt (subopts toplevel-options.layout).preset-column-widths} for more information.
      '';
    };
    render = config: [
      (lib.mkIf (config.default-column-width != null) [
        (kdl.plain "default-column-width" [
          (lib.mapAttrsToList kdl.leaf config.default-column-width)
        ])
      ])
    ];
  }))
  {
    window-rule = {
      options.default-window-height = nullable default-height // {
        description = ''
          The default height for new floating windows.

          This does nothing if the window is not floating when it is created.

          There is no global default option for this in the layout section like for the column width. If the final value of this option is null, then it defaults to the empty attrset ${fmt.code "{}"}.

          If this is set to an empty attrset ${fmt.code "{}"}, then it effectively "unsets" the default height for this window rule evaluation, as opposed to ${fmt.code "null"} which doesn't change the value at all. Future rules may still set it to a value and unset it again as they wish.

          If the final value of this option is an empty attrset ${fmt.code "{}"}, then the client gets to decide the height of the window.

          If the final value of this option is not an empty attrset ${fmt.code "{}"}, and the window spawns as floating, then the window will be created with the specified height.
        '';
      };
      render = config: [
        (lib.mkIf (config.default-window-height != null) [
          (kdl.plain "default-window-height" [
            (lib.mapAttrsToList kdl.leaf config.default-window-height)
          ])
        ])
      ];
    };
  }
  (layout-options.window-level (ctx: {
    options.default-column-display = ctx.nullable "default-column-display" {
      type = types.enum [
        "normal"
        "tabbed"
      ];
      description = ''
        How windows in newly opened columns should be displayed by default.

        ${fmt.list [
          "${fmt.code ''"normal"''}: Windows are arranged vertically, spread across the working area height."
          "${fmt.code ''"tabbed"''}: Windows are arranged in tabs, with only the focused window visible, taking up the full height of the working area."
        ]}

        Note that you can override this for a given column at any time. Every column remembers its own display mode, independent from this setting. This setting controls the default value when a column is ${fmt.em "created"}.

        A newly created column always contains exactly one window. As such, the window rule variant of this option can match on properties of that singular window.
      '';
    };
    render = config: [
      (lib.mkIf (config.default-column-display != null) [
        (kdl.leaf "default-column-display" config.default-column-display)
      ])
    ];
  }))
  (layout-options.workspace-level (ctx: {
    options.center-focused-column = ctx.nullable "center-focused-column" {
      type = types.enum [
        "never"
        "always"
        "on-overflow"
      ];
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
  }))
  (layout-options.workspace-level (ctx: {
    options.always-center-single-column = ctx.nullable "always-center-single-column" {
      type = types.bool;
      description = ''
        This is like ${fmt.code ''center-focused-column = "always";''}, but only for workspaces with a single column. Changes nothing if ${fmt.code "center-focused-column"} is set to ${fmt.code ''"always"''}. Has no effect if more than one column is present.
      '';
    };
    render = config: [
      (lib.mkIf (config.always-center-single-column != null) [
        (kdl.leaf "always-center-single-column" config.always-center-single-column)
      ])
    ];
  }))
  {
    window-rule = {
      options =
        let
          sizing-info = bound: ''
            Sets the ${bound} (in logical pixels) that niri will ever ask this window for.

            Keep in mind that the window itself always has a final say in its size, and may not respect the ${bound} set by this option.
          '';

          sizing-opt =
            bound:
            nullable types.int
            // {
              description = sizing-info bound;
            };
        in
        {
          min-width = sizing-opt "minimum width";
          max-width = sizing-opt "maximum width";
          min-height = sizing-opt "minimum height";
          max-height = nullable types.int // {
            description = ''
              ${sizing-info "maximum height"}

              Also, note that the maximum height is not taken into account when automatically sizing columns. That is, when a column is created normally, windows in it will be "automatically sized" to fill the vertical space. This algorithm will respect a minimum height, and not make windows any smaller than that, but the max height is only taken into account if it is equal to the min height. In other words, it will only accept a "fixed height" or a "minimum height". In practice, most windows do not set a max size unless it is equal to their min size, so this is usually not a problem without window rules.

              If you manually change the window heights, then max-height will be taken into account and restrict you from making it any taller, as you'd intuitively expect.
            '';
          };
        };
      render = config: [
        (lib.mkIf (config.min-width != null) [
          (kdl.leaf "min-width" config.min-width)
        ])
        (lib.mkIf (config.max-width != null) [
          (kdl.leaf "max-width" config.max-width)
        ])
        (lib.mkIf (config.min-height != null) [
          (kdl.leaf "min-height" config.min-height)
        ])
        (lib.mkIf (config.max-height != null) [
          (kdl.leaf "max-height" config.max-height)
        ])
      ];
    };
  }
]
