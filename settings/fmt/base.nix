{
  lib,
  niri-flake-rev,
  fmt,
}:
let
  test = pat: str: lib.strings.match pat str != null;
in
{
  markdown-anchor = lib.flip lib.pipe [
    (lib.replaceStrings (lib.upperChars ++ [ " " ]) (lib.lowerChars ++ [ "-" ]))
    (lib.splitString "")
    (lib.filter (test "[a-z0-9-]"))
    lib.concatStrings
  ];

  link' =
    loc:
    fmt.masked-link {
      href = fmt.link-to-setting loc;
      content = fmt.code (lib.removePrefix "programs.niri.settings." (lib.showOption loc));
    };

  link-opt =
    opt:
    assert opt._type == "option";
    fmt.link' opt.loc;

  link-opt-masked =
    opt: content:
    assert opt._type == "option";
    fmt.masked-link {
      href = fmt.link-to-setting opt.loc;
      inherit content;
    };

  link-opt' = opt: loc: fmt.link-opt-masked opt (fmt.code (lib.showOption loc));

  link-niri-commit =
    {
      rev,
      shortRev,
    }:
    fmt.masked-link {
      href = "https://github.com/YaLTeR/niri/tree/${rev}";
      content = fmt.code shortRev;
    };
  link-niri-release =
    version:
    fmt.masked-link {
      href = "https://github.com/YaLTeR/niri/releases/tag/${version}";
      content = fmt.code version;
    };

  link-stylix-opt =
    opt: "[`${opt}`](https://danth.github.io/stylix/options/hm.html#${fmt.markdown-anchor opt})";

  link-this-github = path: "https://github.com/sodiboo/niri-flake/blob/${niri-flake-rev}/${path}";
}
