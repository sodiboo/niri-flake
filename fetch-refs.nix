with builtins; let
  fetch = repo:
    foldl' (x: f: f x) "https://api.github.com/repos/${repo}/git/refs/tags" [
      fetchurl
      readFile
      fromJSON

      (filter (x: x.object.type == "tag"))

      (map (x: x.object.url))
      (map fetchurl)
      (map readFile)
      (map fromJSON)

      (filter (x: x.object.type == "commit"))

      (map (x: ''"${x.object.sha}" = "${x.tag}";''))

      (concatStringsSep "\n  ")
    ];
in ''
  # This file is generated automatically by fetch-refs.nix
  # Do not edit it manually, your changes will be lost.
  #
  # Both niri and xwayland-satellite are listed.
  # This is because commit hashes are globally unique.
  {
    # niri
    ${fetch "YaLTeR/niri"}
    # xwayland-satellite
    ${fetch "Supreeeme/xwayland-satellite"}
  }
''
