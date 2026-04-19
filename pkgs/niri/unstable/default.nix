{
  callPackage,
  fetchFromGitHub,
  lib,
  ...
}@args:

callPackage ../generic.nix (
  rec {
    version = "25.11-unstable-2026-04-19";
    commitDate =
      let
        inherit (builtins) concatStringsSep splitVersion;
        inherit (lib.lists) sublist;
      in
      concatStringsSep "-" (sublist 3 5 (splitVersion version));
    versionString = "unstable ${commitDate} (commit ${src.rev})";
    src = fetchFromGitHub {
      owner = "YaLTeR";
      repo = "niri";
      rev = "68bb942d2146cd2c8af69c0f16db18396b4388fe";
      hash = "sha256-7Bbp0fDBJMDRpKfdHelMXbhY51bdCa5+Qn/+XONaOwk=";
    };
    cargoHash = "sha256-tievZgYwlZ/zUjl/R6B3UFmFiav9tHxAujxPQjP6niU=";
    replace-service-with-usr-bin = false;
  }
  // args
)
