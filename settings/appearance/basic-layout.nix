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
    optional
    link-opt
    subopts
    nullable
    list
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
in
[
  {
    layout = {
      options.preset-column-widths = nullable (lib.types.nonEmptyListOf preset-width) // {
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

      render = config: [
        (lib.mkIf (config.preset-column-widths != null) [
          (kdl.plain "preset-column-widths" [
            (map (lib.mapAttrsToList kdl.leaf) config.preset-column-widths)
          ])
        ])
      ];
    };
  }
  {
    layout = {
      options.preset-window-heights = nullable (lib.types.nonEmptyListOf preset-height) // {
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
      render = config: [
        (lib.mkIf (config.preset-window-heights != null) [
          (kdl.plain "preset-window-heights" [
            (map (lib.mapAttrsToList kdl.leaf) config.preset-window-heights)
          ])
        ])
      ];
    };
  }
  {
    layout = {
      options.default-column-width = nullable default-width // {
        description = ''
          The default width for new columns.

          When this is set to an empty attrset ${fmt.code "{}"}, windows will get to decide their initial width. This is distinct from null, which represents that this particular layout block has no effect on the default width.

          See ${link-opt (subopts toplevel-options.layout).preset-column-widths} for more information.

          You can override this for specific windows using ${link-opt (subopts toplevel-options.window-rules).default-column-width}
        '';
      };
      render = config: [
        (lib.mkIf (config.default-column-width != null) [
          (kdl.plain "default-column-width" [
            (lib.mapAttrsToList kdl.leaf config.default-column-width)
          ])
        ])
      ];
    };
    window-rule = {
      options.default-column-width = nullable default-width // {
        description = ''
          The default width for new columns.

          If the final value of this option is null, it default to ${link-opt (subopts toplevel-options.layout).default-column-width}

          If the final value option is not null, then its value will take priority over ${link-opt (subopts toplevel-options.layout).default-column-width} for windows matching this rule.

          An empty attrset ${fmt.code "{}"} is not the same as null. When this is set to an empty attrset ${fmt.code "{}"}, windows will get to decide their initial width. When set to null, it represents that this particular window rule has no effect on the default width (and it should instead be taken from an earlier rule or the global default).

        '';
      };
      render = config: [
        (lib.mkIf (config.default-column-width != null) [
          (kdl.plain "default-column-width" [
            (lib.mapAttrsToList kdl.leaf config.default-column-width)
          ])
        ])
      ];
    };
  }
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
  {
    layout = {
      options.default-column-display =
        nullable (
          lib.types.enum [
            "normal"
            "tabbed"
          ]
        )
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
      render = config: [
        (lib.mkIf (config.default-column-display != null) [
          (kdl.leaf "default-column-display" config.default-column-display)
        ])
      ];
    };

    window-rule = {
      options.default-column-display =
        nullable (
          lib.types.enum [
            "normal"
            "tabbed"
          ]
        )
        // {
          description = ''
            When this window is inserted into the tiling layout such that a new column is created (e.g. when it is first opened, when it is expelled from an existing column, when it's moved to a new workspace, etc), this setting controls the default display mode of the column.

            If the final value of this field is null, then the default display mode is taken from ${link-opt (subopts toplevel-options.layout).default-column-display}.
          '';
        };
      render = config: [
        (lib.mkIf (config.default-column-display != null) [
          (kdl.leaf "default-column-display" config.default-column-display)
        ])
      ];
    };
  }
]
