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
        overview = import ./overview.nix {
          inherit
            lib
            kdl
            niri-flake-internal
            toplevel-options
            ;
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
        debug = import ./debug.nix {
          inherit
            lib
            kdl
            niri-flake-internal
            toplevel-options
            ;
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
