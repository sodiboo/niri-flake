{ inputs, ... }:
let
  packageSet = import ./package.nix { inherit inputs; };
in
{
  overlays.niri = final: prev: packageSet final;
}
