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
    nullable
    float-or-int
    optional
    record
    required
    ;

  rendered-options =
    sections: final:
    { config, ... }:
    {
      imports = map (s: { inherit (s) options; }) sections ++ [
        (final (map (s: s.render config) sections))
      ];
    };
in
{
  sections = [
    {
      options.outputs = lib.mkOption {
        default = { };
        type = lib.types.attrsOf (
          lib.types.submodule [
            {
              options.enable = optional types.bool true;
            }
            (
              { name, ... }:
              {
                options.name = lib.mkOption {
                  type = types.str;
                  default = name;
                  defaultText = "the key of the output";
                  description = ''
                    The name of the output. You set this manually if you want the outputs to be ordered in a specific way.
                  '';
                };
              }
            )
            (rendered-options
              (
                [
                  {
                    options.scale = nullable float-or-int // {
                      description = ''
                        The scale of this output, which represents how many physical pixels fit in one logical pixel.

                        If this is null, niri will automatically pick a scale for you.
                      '';
                    };
                    render = config: [
                      (lib.mkIf (config.scale != null) [
                        (kdl.leaf "scale" config.scale)
                      ])
                    ];
                  }
                  {
                    options.transform = {
                      flipped = optional types.bool false // {
                        description = ''
                          Whether to flip this output vertically.
                        '';
                      };
                      rotation =
                        optional (enum [
                          0
                          90
                          180
                          270
                        ]) 0
                        // {
                          description = ''
                            Counter-clockwise rotation of this output in degrees.
                          '';
                        };
                    };
                    render =
                      config:
                      let
                        rotation = toString config.transform.rotation;
                        basic = if config.transform.flipped then "flipped-${rotation}" else "${rotation}";
                        replacement."0" = "normal";
                        replacement."flipped-0" = "flipped";

                        transform = replacement.${basic} or basic;
                      in
                      [
                        (kdl.leaf "transform" transform)
                      ];
                  }
                  {
                    options.position =
                      nullable (record {
                        x = required types.int;
                        y = required types.int;
                      })
                      // {
                        description = ''
                          Position of the output in the global coordinate space.

                          This affects directional monitor actions like "focus-monitor-left", and cursor movement.

                          The cursor can only move between directly adjacent outputs.

                          Output scale has to be taken into account for positioning, because outputs are sized in logical pixels.

                          For example, a 3840x2160 output with scale 2.0 will have a logical size of 1920x1080, so to put another output directly adjacent to it on the right, set its x to 1920.

                          If the position is unset or multiple outputs overlap, niri will instead place the output automatically.
                        '';
                      };
                    render = config: [
                      (lib.mkIf (config.position != null) [
                        (kdl.leaf "position" config.position)
                      ])
                    ];
                  }
                  {
                    options.mode =
                      nullable (record {
                        width = required types.int;
                        height = required types.int;
                        refresh = nullable types.float // {
                          description = ''
                            The refresh rate of this output. When this is null, but the resolution is set, niri will automatically pick the highest available refresh rate.
                          '';
                        };
                      })
                      // {
                        description = ''
                          The resolution and refresh rate of this display.

                          By default, when this is null, niri will automatically pick a mode for you.

                          If this is set to an invalid mode (i.e unsupported by this output), niri will act as if it is unset and pick one for you.
                        '';
                      };
                    render =
                      config:
                      let
                        resolution = "${toString config.mode.width}x${toString config.mode.height}";
                        mode =
                          if config.mode.refresh == null then resolution else "${resolution}@${toString config.mode.refresh}";
                      in
                      [
                        (lib.mkIf (config.mode != null) [
                          (kdl.leaf "mode" mode)
                        ])
                      ];
                  }
                  {
                    options.variable-refresh-rate =
                      optional (enum [
                        false
                        "on-demand"
                        true
                      ]) false
                      // {
                        description = ''
                          Whether to enable variable refresh rate (VRR) on this output.

                          VRR is also known as Adaptive Sync, FreeSync, and G-Sync.

                          Setting this to ${fmt.code ''"on-demand"''} will enable VRR only when a window with ${link-opt (subopts toplevel-options.window-rules).variable-refresh-rate} is present on this output.
                        '';
                      };
                    render = config: [
                      (lib.mkIf (config.variable-refresh-rate != false) [
                        (kdl.leaf "variable-refresh-rate" { on-demand = config.variable-refresh-rate == "on-demand"; })
                      ])
                    ];
                  }
                  {
                    options.focus-at-startup = optional types.bool false // {
                      description = ''
                        Focus this output by default when niri starts.

                        If multiple outputs with ${fmt.code "focus-at-startup"} are connected, then the one with the key that sorts first will be focused. You can change the key to affect the sorting order, and set ${link-opt (subopts toplevel-options.outputs).name} to be the actual name of the output.

                        When none of the connected outputs are explicitly focus-at-startup, niri will focus the first one sorted by name (same output sorting as used elsewhere in niri).
                      '';
                    };
                    render = config: [
                      (lib.mkIf (config.focus-at-startup) [
                        (kdl.flag "focus-at-startup")
                      ])
                    ];
                  }
                ]
                ++ appearance.output
              )
              (
                contents:
                { config, ... }:
                {
                  options.rendered = lib.mkOption {
                    type = kdl.types.kdl-node;
                    readOnly = true;
                    internal = true;
                    visible = false;
                  };
                  config.rendered = kdl.node "output" config.name [
                    (lib.mkIf (!config.enable) (kdl.flag "off"))
                    (lib.mkIf (config.enable) [ contents ])
                  ];
                }
              )
            )
          ]
        );
      };

      render = cfg: map (cfg: cfg.rendered) (builtins.attrValues cfg.outputs);
    }
  ];
}
