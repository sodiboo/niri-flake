{
  lib,
  kdl,
  fragments,
  niri-flake-internal,
  toplevel-options,
}:

let
  inherit (lib) types;

  inherit (niri-flake-internal)
    fmt
    make-ordered-options
    optional
    float-or-int
    link-opt
    subopts
    nullable
    ;

  inherit (fragments) make-decoration-options;

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

  borderish =
    {
      enable-by-default,
      node-name,
      name,
      window,
      matched-window,
      description,
    }:
    {
      layout = {
        options.${node-name} = lib.mkOption {
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
        render = config: config.${node-name}.rendered;
      };

      window-rule = {
        options.${node-name} = lib.mkOption {
          description = ''
            See ${link-opt (subopts toplevel-options.layout).${node-name}}.
          '';
          default = { };
          type = lib.types.submodule (
            { options, ... }:
            {
              imports =
                make-rendered-ordered-options
                  [
                    {
                      options.enable = nullable types.bool // {
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
                      options.width = nullable float-or-int // {
                        description = ''
                          The width of the ${name} drawn around each ${matched-window}.
                        '';
                      };
                      render = config: [
                        (lib.mkIf (config.width != null) [
                          (kdl.leaf "width" config.width)
                        ])
                      ];
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
                        apply = node: lib.mkIf (node.children != [ ]) node;
                      };
                      config.rendered = kdl.plain node-name [ content ];
                    }
                  );
            }
          );
        };
        render = config: config.${node-name}.rendered;
      };
    };

in
[
  (borderish {
    enable-by-default = false;
    node-name = "border";
    name = "border";
    window = "window";
    matched-window = "matched window";
    description = ''
      The border is a decoration drawn ${fmt.em "inside"} every window in the layout. It will take space away from windows. That is, if you have a border of 8px, then each window will be 8px smaller on each edge than if you had no border.

      The currently focused window, i.e. the window that can receive keyboard input, will be drawn according to ${link-opt (subopts (subopts toplevel-options.layout).border).active}, and all other windows will be drawn according to ${link-opt (subopts (subopts toplevel-options.layout).border).inactive}.

      If you have ${link-opt (subopts toplevel-options.layout).focus-ring} enabled, the border will be drawn inside (and over) the focus ring.
    '';
  })
  (borderish {
    enable-by-default = true;
    node-name = "focus-ring";
    name = "focus ring";
    window = "focused window";
    matched-window = "matched window with focus";
    description = ''
      The focus ring is a decoration drawn ${fmt.em "around"} the last focused window on each monitor. It takes no space away from windows. If you have insufficient gaps, the focus ring can be drawn over adjacent windows, but it will never affect the layout of windows.

      The focused window of the currently focused monitor, i.e. the window that can receive keyboard input, will be drawn according to ${link-opt (subopts (subopts toplevel-options.layout).focus-ring).active}, and the last focused window on all other monitors will be drawn according to ${link-opt (subopts (subopts toplevel-options.layout).focus-ring).inactive}.

      If you have ${link-opt (subopts toplevel-options.layout).border} enabled, the focus ring will be drawn around (and under) the border.
    '';
  })
]
