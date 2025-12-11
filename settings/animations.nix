{
  lib,
  kdl,
  niri-flake-internal,
  toplevel-options,
}:
let
  inherit (lib)
    types
    mkOption
    mkOptionType
    showOption
    ;

  inherit (lib.types) enum nullOr;

  inherit (niri-flake-internal)
    fmt
    list
    make-ordered-options
    record
    shorthand-for
    obsolete-warning
    rename-warning
    docs-only
    float-or-int
    nullable
    required
    optional
    section
    section'
    ;

  animation-kind = types.attrTag {
    spring = section {
      damping-ratio = required types.float;
      stiffness = required types.int;
      epsilon = required types.float;
    };
    easing = section {
      duration-ms = required types.int;
      curve =
        required (enum [
          "linear"
          "ease-out-quad"
          "ease-out-cubic"
          "ease-out-expo"
          "cubic-bezier"
        ])
        // {
          description = ''
            The curve to use for the easing function.
          '';
        };

      # eh? not loving this. but anything better is kinda nontrivial.
      # will refactor, currently just a stopgap so that it is usable.
      curve-args = list kdl.types.kdl-value // {
        description = ''
          Arguments to the easing curve. ${fmt.code "cubic-bezier"} requires 4 arguments, all others don't allow arguments.
        '';
      };
    };
  };

  make-animation-option =
    animation-name:
    {
      has-shader ? false,
    }:
    {
      options.${animation-name} = nullable (
        types.submodule (
          { config, ... }:
          {
            options = {
              enable = optional types.bool true;
              kind = nullable (shorthand-for "animation-kind" animation-kind) // {
                visible = "shallow";
              };
            }
            // lib.optionalAttrs has-shader {
              custom-shader = nullable types.str // {
                description = ''
                  Source code for a GLSL shader to use for this animation.

                  For example, set it to ${fmt.code "builtins.readFile ./${animation-name}.glsl"} to use a shader from the same directory as your configuration file.

                  See: ${fmt.bare-link "https://github.com/YaLTeR/niri/wiki/Configuration:-Animations#custom-shader"}
                '';
              };
            }
            // {
              rendered = lib.mkOption {
                type = kdl.types.kdl-node;
                readOnly = true;
                internal = true;
                visible = false;
              };
            };

            config.rendered = kdl.plain animation-name [
              (lib.mkIf (!config.enable) (kdl.flag "off"))
              (lib.mkIf (config.enable) [
                (lib.mkIf (config.kind ? easing) [
                  (kdl.leaf "duration-ms" config.kind.easing.duration-ms)
                  (kdl.leaf "curve" ([ config.kind.easing.curve ] ++ config.kind.easing.curve-args))
                ])
                (lib.mkIf (config.kind ? spring) [
                  (kdl.leaf "spring" config.kind.spring)
                ])
                (lib.optional has-shader [
                  (lib.mkIf (config.custom-shader != null) [
                    (kdl.leaf "custom-shader" config.custom-shader)
                  ])
                ])
              ])
            ];
          }
        )
      );
      render = config: [
        (lib.mkIf (config.${animation-name} != null) [
          config.${animation-name}.rendered
        ])
      ];
    };

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
      options.animations =
        rendered-ordered-section
          [
            {
              options.enable = nullable types.bool;
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
              options.slowdown = nullable float-or-int;
              render = config: [
                (lib.mkIf (config.slowdown != null) [
                  (kdl.leaf "slowdown" config.slowdown)
                ])
              ];
            }
            (make-animation-option "workspace-switch" { })
            (make-animation-option "horizontal-view-movement" { })
            (make-animation-option "config-notification-open-close" { })
            (make-animation-option "exit-confirmation-open-close" { })
            (make-animation-option "window-movement" { })
            (make-animation-option "window-open" { has-shader = true; })
            (make-animation-option "window-close" { has-shader = true; })
            (make-animation-option "window-resize" { has-shader = true; })
            (make-animation-option "screenshot-ui-open" { })
            (make-animation-option "overview-open-close" { })
            {
              options."<animation-kind>" = docs-only animation-kind // {
                override-loc = lib.const [ "<animation-kind>" ];
              };
              render = _: [ ];
            }
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

              config.rendered = kdl.plain "animations" [ content ];
            }
          );

      render = config: config.animations.rendered;
    }
  ];
}
