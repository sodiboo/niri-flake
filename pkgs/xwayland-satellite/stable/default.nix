{ callPackage, fetchFromGitHub, ... }@args:

callPackage ../generic.nix (
  rec {
    version = "0.7";
    versionString = "stable v${version} (commit ${src.rev})";
    src = fetchFromGitHub {
      owner = "Supreeeme";
      repo = "xwayland-satellite";
      rev = "v${version}";
      hash = "sha256-m+9tUfsmBeF2Gn4HWa6vSITZ4Gz1eA1F5Kh62B0N4oE=";
    };
    cargoHash = "sha256-2+qQSCyWOtOJ4fTVCHbvHYO+k4vxC2nbEOJMdjQZOgY=";
  }
  // args
)
