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
    ordered-section
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

  anims = {
    workspace-switch.has-shader = false;
    horizontal-view-movement.has-shader = false;
    config-notification-open-close.has-shader = false;
    exit-confirmation-open-close.has-shader = false;
    window-movement.has-shader = false;
    window-open.has-shader = true;
    window-close.has-shader = true;
    window-resize.has-shader = true;
    screenshot-ui-open.has-shader = false;
    overview-open-close.has-shader = false;
  };
in
{
  sections = [
    {
      options.animations = ordered-section [
        {
          enable = optional types.bool true;
          slowdown = nullable float-or-int;
        }
        {
          all-anims = mkOption {
            type = types.raw;
            internal = true;
            visible = false;

            default = builtins.attrNames anims;
          };
        }
        (builtins.mapAttrs (
          name:
          (
            { has-shader }:
            let
              inner = record (
                {
                  enable = optional types.bool true;
                  kind = nullable (shorthand-for "animation-kind" animation-kind) // {
                    visible = "shallow";
                  };
                }
                // lib.optionalAttrs has-shader {
                  custom-shader = nullable types.str // {
                    description = ''
                      Source code for a GLSL shader to use for this animation.

                      For example, set it to ${fmt.code "builtins.readFile ./${name}.glsl"} to use a shader from the same directory as your configuration file.

                      See: ${fmt.bare-link "https://github.com/YaLTeR/niri/wiki/Configuration:-Animations#custom-shader"}
                    '';
                  };
                }
              );

              actual-type = mkOptionType {
                inherit (inner)
                  name
                  description
                  getSubOptions
                  nestedTypes
                  ;

                check = value: builtins.isNull value || animation-kind.check value || inner.check value;
                merge =
                  loc: defs:
                  inner.merge loc (
                    map (
                      def:
                      if builtins.isNull def.value then
                        lib.warn (obsolete-warning "${showOption loc} = null;" "${
                          showOption (loc ++ [ "enable" ])
                        } = false;" [ def ]) def
                        // {
                          value.enable = false;
                        }
                      else if animation-kind.check def.value then
                        lib.warn (rename-warning loc (loc ++ [ "kind" ]) [ def ]) def // { value.kind = def.value; }
                      else
                        def
                    ) defs
                  );
              };
            in
            optional actual-type { }
          )
        ) anims)
        {
          "<animation-kind>" = docs-only animation-kind // {
            override-loc = lib.const [ "<animation-kind>" ];
          };
        }
        (
          let
            deprecated-shaders = [
              "window-open"
              "window-close"
              "window-resize"
            ];
          in
          {
            __module =
              {
                options,
                config,
                ...
              }:
              {
                options.shaders = lib.genAttrs deprecated-shaders (
                  _: required (nullOr types.str) // { visible = false; }
                );
                config = lib.genAttrs deprecated-shaders (
                  name:
                  let
                    old = options.shaders.${name};
                  in
                  lib.mkIf (old.isDefined) (
                    lib.warn
                      (rename-warning (old.loc) (options.${name}.loc ++ [ "custom-shader" ]) old.definitionsWithLocations)
                      {
                        custom-shader = config.shaders.${name};
                      }
                  )
                );
              };
          }
        )
      ];
    }
  ];
}
