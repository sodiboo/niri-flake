{
  callPackage,
  fetchFromGitHub,
}:
callPackage ../generic.nix rec {
  version = "0.7";
  versionString = "stable v${version} (commit ${src.rev})";
  src = fetchFromGitHub {
    owner = "Supreeeme";
    repo = "xwayland-satellite";
    rev = "388d291e82ffbc73be18169d39470f340707edaa";
    hash = "sha256-m+9tUfsmBeF2Gn4HWa6vSITZ4Gz1eA1F5Kh62B0N4oE=";
  };
  cargoLock = {
    lockFile = "${src}/Cargo.lock";
  };
}
