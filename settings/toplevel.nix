{
  lib,
  config,
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
    make-ordered-options
    ;
in

let
  files =
    map
      (
        f:
        import f {
          inherit
            lib
            kdl
            niri-flake-internal
            toplevel-options
            ;
        }
      )
      [
        ./input.nix
        ./outputs.nix
        ./binds.nix
        ./switch-events.nix
        ./layout.nix
        ./overview.nix

        ./workspaces.nix

        ./misc.nix

        ./surface-rules.nix
        ./animations.nix
        ./gestures.nix

        ./debug.nix
      ];

  sections = builtins.concatMap (f: f.sections or [ ]) files;
in
{
  imports = (make-ordered-options (map (s: s.options) sections));
}
