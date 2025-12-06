{
  lib,
  options,

  kdl,
  niri-flake-internal,
  ...
}:
let
  toplevel-options = options;
  inherit (lib)
    types
    ;
  inherit (lib.types) nullOr enum;
  inherit (niri-flake-internal)
    fmt
    link-opt
    subopts
    section'
    make-ordered-options
    nullable
    float-or-int
    section
    record
    required
    shadow-descriptions
    list
    attrs
    attrs-record
    optional
    ;
in
{
  # config._module.niri-flake-ordered-record.ordering = lib.mkForce [
  #   "input"
  #   "outputs"
  #   "binds"
  #   "switch-events"
  #   "layout"

  #   "workspaces"

  #   "spawn-at-startup"
  #   "prefer-no-csd"
  #   "screenshot-path"
  #   "environment"
  #   "overview"
  #   "cursor"
  #   "xwayland-satellite"
  #   "clipboard"
  #   "hotkey-overlay"

  #   "window-rules"
  #   "layer-rules"
  #   "animations"
  #   "gestures"

  #   "debug"
  # ];
  imports = make-ordered-options (
    [
      {
        switch-events = import ./switch-events.nix {
          inherit
            lib
            kdl
            niri-flake-internal
            toplevel-options
            ;
        };

        binds = import ./binds.nix {
          inherit
            lib
            kdl
            niri-flake-internal
            toplevel-options
            ;
        };
      }
      {
        workspaces = import ./workspaces.nix {
          inherit
            lib
            kdl
            niri-flake-internal
            toplevel-options
            ;
        };
      }

      {
        overview = {
          zoom = nullable float-or-int // {
            description = ''
              Control how much the workspaces zoom out in the overview. zoom ranges from 0 to 0.75 where lower values make everything smaller.
            '';
          };
          backdrop-color = nullable types.str // {
            description = ''
              Set the backdrop color behind workspaces in the overview. The backdrop is also visible between workspaces when switching.

              The alpha channel for this color will be ignored.
            '';
          };

          workspace-shadow = {
            enable = optional types.bool true;
            offset =
              nullable (record {
                x = optional float-or-int 0.0;
                y = optional float-or-int 5.0;
              })
              // {
                description = shadow-descriptions.offset;
              };

            softness = nullable float-or-int // {
              description = shadow-descriptions.softness;
            };

            spread = nullable float-or-int // {
              description = shadow-descriptions.spread;
            };

            color = nullable types.str;
          };
        };
      }

      {
        input = import ./input.nix {
          inherit
            lib
            kdl
            niri-flake-internal
            toplevel-options
            ;
        };
      }

      {
        outputs = import ./outputs.nix {
          inherit
            lib
            kdl
            niri-flake-internal
            toplevel-options
            ;
        };
      }

      {
        layout = import ./layout.nix {
          inherit
            lib
            kdl
            niri-flake-internal
            toplevel-options
            ;
        };
      }

      {
        animations = import ./animations.nix {
          inherit
            lib
            kdl
            niri-flake-internal
            toplevel-options
            ;
        };

        gestures = import ./gestures.nix {
          inherit
            lib
            kdl
            niri-flake-internal
            toplevel-options
            ;
        };
      }
      (import ./surface-rules.nix {
        inherit
          lib
          kdl
          niri-flake-internal
          toplevel-options
          ;
      })
      {
        debug = attrs kdl.types.kdl-args // {
          description = ''
            Debug options for niri.

            ${fmt.code "kdl arguments"} in the type refers to a list of arguments passed to a node under the ${fmt.code "debug"} section. This is a way to pass arbitrary KDL-valid data to niri. See ${link-opt (subopts options.binds).action} for more information on all the ways you can use this.

            Note that for no-argument nodes, there is no special way to define them here. You can't pass them as just a "string" because that makes no sense here. You must pass it an empty array of arguments.

            Here's an example of how to use this:

            ${fmt.nix-code-block ''
              {
                ${options.debug} = {
                  disable-cursor-plane = [];
                  render-drm-device = "/dev/dri/renderD129";
                };
              }
            ''}

            This option is, just like ${link-opt (subopts options.binds).action}, not verified by the nix module. But, it will be validated by niri before committing the config.

            Additionally, i don't guarantee stability of the debug options. They may change at any time without prior notice, either because of niri changing the available options, or because of me changing this to a more reasonable schema.
          '';
        };
      }
    ]
    ++ (import ./misc.nix {
      inherit
        lib
        kdl
        niri-flake-internal
        toplevel-options
        ;
    })
  );
}
