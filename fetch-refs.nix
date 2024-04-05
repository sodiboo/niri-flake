with builtins;
  foldl' (x: f: f x) "https://api.github.com/repos/YaLTeR/niri/git/refs/tags" [
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
    (tags: ''
      # This file is generated automatically by fetch-refs.nix
      # Do not edit it manually, your changes will be lost.
      {
        ${tags}
      }
    '')
  ]
