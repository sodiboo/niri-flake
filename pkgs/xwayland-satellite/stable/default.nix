{ callPackage, fetchFromGitHub, ... }@args:

callPackage ../generic.nix (
  rec {
    version = "0.8.1";
    versionString = "stable v${version} (commit ${src.rev})";
    src = fetchFromGitHub {
      owner = "Supreeeme";
      repo = "xwayland-satellite";
      rev = "v${version}";
      hash = "sha256-BUE41HjLIGPjq3U8VXPjf8asH8GaMI7FYdgrIHKFMXA=";
    };
    cargoHash = "sha256-16L6gsvze+m7XCJlOA1lsPNELE3D364ef2FTdkh0rVY=";
  }
  // args
)
