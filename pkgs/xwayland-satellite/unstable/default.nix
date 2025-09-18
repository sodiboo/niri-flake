{
  callPackage,
  fetchFromGitHub,
}:
callPackage ../generic.nix rec {
  version = "0.7-unstable-2025-09-06";
  versionString = "${version} (commit ${src.rev})";
  src = fetchFromGitHub {
    owner = "Supreeeme";
    repo = "xwayland-satellite";
    rev = "970728d0d9d1eada342bb8860af214b601139e58";
    hash = "sha256-TIvyWzRt1miQj6Cf5Wy8Qz43XIZX7c4vTVwRLAT5S4Y=";
  };
  cargoHash = "sha256-ISdzrXAgL6RFQOfXS7+o2Q8WVbgvX351G2DCSapAfnE=";
}
