{
  callPackage,
  fetchFromGitHub,
}:
callPackage ../generic.nix rec {
  version = "25.08-unstable-2025-09-14";
  versionString = "${version} (commit ${src.rev})";
  src = fetchFromGitHub {
    owner = "YaLTeR";
    repo = "niri";
    rev = "e6a8ad38479eb179dc7301755316f993e3e872ea";
    hash = "sha256-SCdus7r4IS8l3jzF8mcMFMlDvACTdmDCcsPnGUEqll0=";
  };
  cargoLock = {
    lockFile = "${src}/Cargo.lock";
    outputHashes = {
      "libspa-0.8.0" = "sha256-twzqBGGprxXgQAtfp2ny+9pTdAQN4S+QHQlNXz+d+H0=";
      "smithay-0.7.0" = "sha256-dCsCeDyMi5kLdbhk5y2OJdAknkbblgRR7sqc558MOEA=";
    };
  };
}
