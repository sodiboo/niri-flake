{
  callPackage,
  fetchFromGitHub,
}:
callPackage ../generic.nix rec {
  version = "25.08";
  versionString = "stable v${version} (commit ${src.rev})";
  src = fetchFromGitHub {
    owner = "YaLTeR";
    repo = "niri";
    rev = "01be0e65f4eb91a9cd624ac0b76aaeab765c7294";
    hash = "sha256-RLD89dfjN0RVO86C/Mot0T7aduCygPGaYbog566F0Qo=";
  };
  cargoLock = {
    lockFile = ./Cargo.lock;
    outputHashes = {
      "libspa-0.8.0" = "sha256-twzqBGGprxXgQAtfp2ny+9pTdAQN4S+QHQlNXz+d+H0=";
      "smithay-0.7.0" = "sha256-dCsCeDyMi5kLdbhk5y2OJdAknkbblgRR7sqc558MOEA=";
    };
  };
}
