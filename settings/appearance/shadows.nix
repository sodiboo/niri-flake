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
    float-or-int
    link-opt
    record
    required
    subopts
    ;

  inherit (hierarchies) overview-options layout-options;

  css-box-shadow =
    prop:
    fmt.masked-link {
      href = "https://developer.mozilla.org/en-US/docs/Web/CSS/box-shadow#syntax";
      content = "CSS box-shadow ${prop}";
    };

  shadow-options = ctx: [
    {
      options.offset = ctx.nullable "offset" {
        type = record {
          x = required float-or-int;
          y = required float-or-int;
        };
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
      options.softness = ctx.nullable "softness" {
        type = float-or-int;
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
      options.spread = ctx.nullable "spread" {
        type = float-or-int;
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
      options.draw-behind-window = ctx.nullable "draw-behind-window" { type = types.bool; };
      render = config: [
        (lib.mkIf (config.draw-behind-window != null) [
          (kdl.leaf "draw-behind-window" config.draw-behind-window)
        ])
      ];
    }
    {
      options.color = ctx.nullable "color" { type = types.str; };
      render = config: [
        (lib.mkIf (config.color != null) [
          (kdl.leaf "color" config.color)
        ])
      ];
    }
  ];
in
[
  (layout-options.surface-agnostic (ctx: {
    options.shadow = ctx.rendered-section "shadow" { partial = true; } (ctx: [
      (ctx.window-level (ctx: {
        options.enable = ctx.nullable "enable" {
          type = types.bool;

          description =
            if ctx.is-window-level then
              ''
                Whether to enable shadows on this window.
              ''
            else
              ''
                Whether to enable shadows for ${
                  {
                    "global" = "all windows";
                    "output" = "windows on this output";
                    "workspace" = "windows in this workspace";
                    "window" = "this window";
                  }
                  .${ctx.position}
                }.

                ${lib.optionalString (!ctx.is-window-level) ''
                  Note that while shadow properties defined in this section generally apply to layer surfaces, this option is an exception. To use shadows on layer surfaces, you must specifically set ${link-opt (subopts (subopts toplevel-options.layer-rules).shadow).enable} to ${fmt.code "true"}.
                ''}
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
      }))
      (ctx.detach-layer-level (ctx: {
        options.enable = ctx.nullable "enable" {
          type = types.bool;

          description = ''
            Whether to enable shadows for this layer surface.

            Note that while shadow properties are generally inherited from the workspace layout, this option is an exception. ${link-opt (subopts (subopts (subopts toplevel-options.workspaces).layout).shadow).enable} has no effect on this option. To use shadows on layer surfaces, you must explicitly set this option to true.
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
      }))
      (shadow-options ctx)
      {
        options.inactive-color = ctx.nullable "inactive-color" { type = types.str; };
        render = config: [
          (lib.mkIf (config.inactive-color != null) [
            (kdl.leaf "inactive-color" config.inactive-color)
          ])
        ];
      }
    ]);
    render = config: config.shadow.rendered;
  }))
  (overview-options.global-level (ctx: {
    options.workspace-shadow = ctx.rendered-section "workspace-shadow" { partial = true; } (ctx: [
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
      (shadow-options ctx)
    ]);
    render = config: config.workspace-shadow.rendered;
  }))
]
