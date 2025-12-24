{
  niri-flake ? builtins.getFlake (toString ../.),

  system ? builtins.currentSystem,
  nixpkgs ? niri-flake.inputs.nixpkgs,

  lib ? nixpkgs.lib,
  pkgs ? nixpkgs.legacyPackages.${system},

  kdl ? niri-flake.lib.kdl,

  settings-fmt ? niri-flake.lib.internal.settings-fmt,
}:
let
  call = file: pkgs.callPackage file { inherit kdl settings-fmt; };
in
pkgs.runCommand "niri-flake-pages" { } ''
  mkdir $out
  ln -s ${../assets} $out/assets
  ln -s ${./base.css} $out/base.css
  ln -s ${call ./settings.html.nix} $out/settings.html
  ln -s ${./settings.css} $out/settings.css
  ln -s ${./settings.js} $out/settings.js
''
