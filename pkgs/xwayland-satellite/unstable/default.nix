{
  callPackage,
  fetchFromGitHub,
  lib,
  ...
}@args:

callPackage ../generic.nix (
  rec {
    version = "0.8.1-unstable-2026-03-16";
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
      rev = "a879e5e0896a326adc79c474bf457b8b99011027";
      hash = "sha256-wToKwH7IgWdGLMSIWksEDs4eumR6UbbsuPQ42r0oTXQ=";
    };
    cargoHash = "sha256-jbEihJYcOwFeDiMYlOtaS8GlunvSze80iWahDj1qDrs=";
  }
  // args
)
