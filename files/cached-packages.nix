{
  lib,
  inputs,
  ...
}:
let
  combinedClosure = import ./combined-closure.nix {
    inherit lib inputs;
  };
in
pkgs: system:
pkgs.legacyPackages.${system}.runCommand "all-niri-flake-packages" { } (
  ''
    mkdir $out
  ''
  + builtins.concatStringsSep "" (
    pkgs.lib.mapAttrsToList
      (name: nixpkgs': ''
        ln -s ${combinedClosure name nixpkgs'.legacyPackages.${system}} $out/${name}
      '')
      {
        nixos-unstable = inputs.nixpkgs;
        "nixos-25.11" = inputs.nixpkgs-stable;
      }
  )
)
