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
  settings-html = builtins.toFile "settings.html" (
    import ./settings.html.nix { inherit lib kdl settings-fmt; }
  );
  picocss = pkgs.fetchFromGitHub {
    owner = "picocss";
    repo = "pico";
    tag = "v2.1.1";
    hash = "sha256-fGQWYKCpprE9FvU7mbgxks41t8x7GsGvhkzVV95dgec=";
  };
in
pkgs.runCommand "niri-flake-pages" { } ''
  mkdir $out
  ln -s ${settings-html} $out/settings.html
  ln -s ${picocss}/css $out/css
  ln -s ${../assets} $out/assets
''
