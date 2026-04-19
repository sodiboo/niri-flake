{ callPackage, fetchFromGitHub, ... }@args:

callPackage ../generic.nix (
  rec {
    version = "25.11";
    versionString = "stable v${version} (commit ${src.rev})";
    src = fetchFromGitHub {
      owner = "YaLTeR";
      repo = "niri";
      rev = "b35bcae35b3f9665043c335e55ed5828af77db85";
      hash = "sha256-FC9eYtSmplgxllCX4/3hJq5J3sXWKLSc7at8ZUxycVw=";
    };
    cargoHash = "sha256-X28M0jyhUtVtMQAYdxIPQF9mJ5a77v8jw1LKaXSjy7E=";
    replace-service-with-usr-bin = true;
  }
  // args
)
