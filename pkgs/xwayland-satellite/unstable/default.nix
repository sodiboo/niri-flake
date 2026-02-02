{
  callPackage,
  fetchFromGitHub,
  lib,
  ...
}@args:

callPackage ../generic.nix (
  rec {
    version = "0.8-unstable-2026-01-29";
    versionString =
      let
        inherit (builtins) concatStringsSep splitVersion;
        inherit (lib.lists) sublist;
        date = concatStringsSep "-" (sublist 3 5 (splitVersion version));
      in
      "unstable ${date} (commit ${src.rev})";
    src = fetchFromGitHub {
      owner = "Supreeeme";
      repo = "xwayland-satellite";
      rev = "37ec78ee26e158b71f42e113e0e7dd9d5eb6bdb0";
      hash = "sha256-0BtCSO2qzYK/akRDsERqRVLknCYD3FYErc+szreSHUo=";
    };
    cargoHash = "sha256-16L6gsvze+m7XCJlOA1lsPNELE3D364ef2FTdkh0rVY=";
  }
  // args
)
