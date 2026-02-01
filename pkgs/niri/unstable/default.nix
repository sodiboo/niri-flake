{
  callPackage,
  fetchFromGitHub,
  lib,
  ...
}@args:

callPackage ../generic.nix (
  rec {
    version = "25.11-unstable-2026-01-28";
    versionString =
      let
        inherit (builtins) concatStringsSep splitVersion;
        inherit (lib.lists) sublist;
        date = concatStringsSep "-" (sublist 3 5 (splitVersion version));
      in
      "unstable ${date} (commit ${src.rev})";
    src = fetchFromGitHub {
      owner = "YaLTeR";
      repo = "niri";
      rev = "f30db163b5748e8cf95c05aba77d0d3736f40543";
      hash = "sha256-v9vz9Rj4MGwPuhGELdvpRKl2HH+xvkgat6VwL0L86Fg=";
    };
    cargoHash = "sha256-mkdn5QY0tWSQ1GhanMNu7v6KiaooSs2oYuvskvzVD3s=";
    replace-service-with-usr-bin = false;
  }
  // args
)
