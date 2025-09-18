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
  cargoHash = "sha256-lR0emU2sOnlncN00z6DwDIE2ljI+D2xoKqG3rS45xG0=";
}
