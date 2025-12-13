{
  lib,
  niri-flake-rev ? "main",
}:
builtins.mapAttrs
  (
    _: f:
    let
      base = import ./base.nix { inherit lib fmt niri-flake-rev; };
      overlay = import f { inherit lib fmt; };
      fmt = base // overlay.fmt;
    in
    overlay // { inherit fmt; }
  )
  {
    gfm = ./gfm.nix;
    html = ./html.nix;
  }
