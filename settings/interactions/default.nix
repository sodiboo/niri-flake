{
  lib,
  niri-flake-utils,
  niri-flake-internal,
  toplevel-options,
  ...
}@args:
let
  inherit (niri-flake-internal) subopts;

  inherit (niri-flake-utils) hierarchy;

  gesture-options =
    f:
    let
      at-position =
        position:
        f (
          hierarchy.make-hierarchical-options {
            scope = [
              "output"
            ];
            inherit position;
            hierarchy = [
              (hierarchy.tree.node "global" {
                options = subopts toplevel-options.gestures;
                children = [
                  (hierarchy.tree.node "output" {
                    options = subopts toplevel-options.outputs;
                  })
                ];
              })
            ];
          }
        );
    in
    {
      gesture = at-position "global";
      output = at-position "output";
    };

  args' = args // {
    hierarchies = {
      gesture-options.global-level = f: gesture-options (ctx: ctx.global-level f);
      gesture-options.output-level = f: gesture-options (ctx: ctx.output-level f);
    };
  };

  elements = lib.zipAttrs (
    builtins.concatMap (f: map (builtins.mapAttrs (_: lib.setDefaultModuleLocation f)) (import f args'))
      [
        ./hot-corners.nix
      ]
  );
in
{
  gestures = elements.gesture or [ ];
  output = elements.output or [ ];
}
