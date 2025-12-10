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
            fragments
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

  fragments = lib.mergeAttrsList (builtins.map (f: f.fragments or { }) files);

  sections = builtins.concatMap (f: f.sections or [ ]) files;
in
{
  imports = (make-ordered-options (map (s: s.options) sections));
  options.rendered = lib.mkOption {
    type = kdl.types.kdl-document;
    readOnly = true;
  };
  config.rendered = map (s: (s.render or (_: [ ])) config) sections;
}
