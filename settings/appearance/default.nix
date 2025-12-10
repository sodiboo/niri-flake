{ lib, ... }@args:
let
  elements = lib.zipAttrs (
    builtins.concatMap (f: import f args) [
      ./decorations.nix
    ]
  );
in
{
  layout = elements.layout or [ ];
  window-rules = elements.window-rule or [ ];
  layer-rules = elements.layer-rule or [ ];
}
