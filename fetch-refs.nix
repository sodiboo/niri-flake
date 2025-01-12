with builtins; let
  fetch = repo:
    foldl' (x: f: f x) "https://api.github.com/repos/${repo}/git/refs/tags" [
      fetchurl
      readFile
      fromJSON

      (map (y:
        if y.object.type == "tag"
        then
          # on basically all releases, the ref points to a tag
          # this is neat, because it wraps the commit hash in a `tag` name.
          foldl' (x: f: f x) y.object.url [
            fetchurl
            readFile
            fromJSON
          ]
        else let
          startsWith = prefix: string: substring 0 (stringLength prefix) string == prefix;
          removePrefix = prefix: string: assert startsWith prefix string; substring (stringLength prefix) (stringLength string) string;
        in
          # but on some releases, the ref directly points to the commit
          # then we have to manually extract the ""tag"" name (not a real tag; but to humans there is no difference)
          y // {tag = removePrefix "refs/tags/" y.ref;}))

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
