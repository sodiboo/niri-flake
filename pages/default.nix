{
  niri-flake ? builtins.getFlake "git+file:${toString ../.}",
  rev ? niri-flake.lib.internal.rev,

  system ? builtins.currentSystem,
  nixpkgs ? niri-flake.inputs.nixpkgs,

  lib ? nixpkgs.lib,
  pkgs ? nixpkgs.legacyPackages.${system},

  kdl ? niri-flake.lib.kdl,

  settings-fmt ? niri-flake.lib.internal.settings-fmt,
}:
let
  call = file: pkgs.callPackage file { inherit kdl rev settings-fmt; };
in
pkgs.runCommand "niri-flake-pages" { } ''
  mkdir $out
  ln -s ${../assets} $out/assets
  ln -s ${./base.css} $out/base.css
  ln -s ${call ./settings.xml.nix} $out/settings.xml
  ln -s ${./settings.xsl} $out/settings.xsl
  ${lib.getExe' pkgs.libxslt "xsltproc"} --output $out/settings.html $out/settings.xsl $out/settings.xml
  ln -s ${./settings.css} $out/settings.css
  ln -s ${./settings.js} $out/settings.js
''
