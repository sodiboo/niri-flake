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
  cargoHash = "sha256-lR0emU2sOnlncN00z6DwDIE2ljI+D2xoKqG3rS45xG0=";
}
