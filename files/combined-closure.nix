{ lib, inputs, ... }:
let
  packageSet = import ./package.nix {
    inherit inputs;
  };
in
pkgs-name: pkgs:
pkgs.runCommand "niri-flake-packages-for-${pkgs-name}" { } (
  ''
    mkdir $out
  ''
  + builtins.concatStringsSep "" (
    lib.mapAttrsToList (name: package: ''
      ln -s ${package} $out/${name}
    '') (packageSet pkgs)
  )
)
