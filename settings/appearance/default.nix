{ lib, ... }@args:
let
  elements = lib.zipAttrs (
    builtins.concatMap (f: map (builtins.mapAttrs (_: lib.setDefaultModuleLocation f)) (import f args))
      [
        ./background.nix
        ./decorations.nix
        ./shadows.nix
        ./basic-layout.nix
      ]
  );
in
{
  layout = elements.layout or [ ];
  window-rules = elements.window-rule or [ ];
  layer-rules = elements.layer-rule or [ ];
  overview = elements.overview or [ ];
  output = elements.output or [ ];
}
