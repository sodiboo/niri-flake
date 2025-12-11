{ lib, ... }@args:
let
  elements = lib.zipAttrs (
    builtins.concatMap (f: map (builtins.mapAttrs (_: lib.setDefaultModuleLocation f)) (import f args))
      [
        ./hot-corners.nix
      ]
  );
in
{
  gestures = elements.gesture or [ ];
  output = elements.output or [ ];
}
