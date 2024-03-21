{lib, ...}:
with lib; let
  match = name: cases: cases.${name} or cases._;
  indent = entries: "${pipe entries [
    toList
    (concatStringsSep "\n")
    (splitString "\n")
    (map (s: "  ${s}"))
    (concatStringsSep "\n")
  ]}";

  delimit = start: content: end: concatStringsSep "\n" [start content end];
  render = v:
    match (builtins.typeOf v) {
      string = lib.strings.escapeNixString v;
      int = toString v;
      float = toString v;
      bool =
        if v
        then "true"
        else "false";
      set =
        if v == {}
        then null
        else delimit "{" (indent (mapAttrsToList (name: val: "${name} = ${render val};") v)) "}";
      null = "null";
      list =
        if v == []
        then null
        else delimit "[" (indent (map render v)) "]";
      _ = "<${(builtins.typeOf v)}>";
    };

  describe = path: opt: {
    ${showOption path} =
      opt
      // {
        defaultText =
          opt.defaultText
          or (
            if opt ? default
            then render opt.default
            else null
          );
      };
  };

  traverse = path: v: (
    if (v ? _type && v._type == "option")
    then (optionalAttrs (v.visible or true != false) (describe path v)) // (optionalAttrs (v.visible or true == true) (traverse path (v.type.getSubOptions v.loc)))
    else concatMapAttrs (name: traverse (path ++ [name])) (filterAttrs (name: const (name != "_module")) v)
  );

  maybe = f: v:
    if v != null
    then f v
    else null;

  unstable-note = ''
    > [!important]
    > This option is not yet available in stable niri.
    >
    > If you wish to modify this option, you should make sure ${link' "programs.niri.package"} is set to ${pkg-link "niri-unstable"}.
    >
    > Otherwise, your system might fail to build.
  '';

  section = contents:
    mkOption {
      type = mkOptionType {name = "docs-override";};
      description = contents;
    };

  header = title: section "# ${title}";
  fake-option = loc: contents:
    section ''
      ## `${loc}`

      ${contents}
    '';

  link-niri-commit = {
    rev,
    shortRev,
  }: "[`${shortRev}`](https://github.com/YaLTeR/niri/tree/${rev})";
  link-niri-release = tag: "[`${tag}`](https://github.com/YaLTeR/niri/releases/tag/${tag})";

  link-stylix-opt = opt: "[`${opt}`](https://danth.github.io/stylix/options/hm.html#${anchor opt})";

  test = pat: str: strings.match pat str != null;

  anchor = flip pipe [
    (replaceStrings (upperChars ++ [" "]) (lowerChars ++ ["-"]))
    (splitString "")
    (filter (test "[a-z0-9-]"))
    concatStrings
  ];
  anchor' = loc: anchor "`${loc}`";

  link = title: "[${title}](#${anchor title})";
  link' = loc: "[`${removePrefix "programs.niri.settings." loc}`](#${anchor "`${loc}`"})";

  module-doc = name: desc: opts:
    {
      _ = section ''
        # `${name}`

        ${desc}
      '';
    }
    // opts;

  pkg-header = name: "packages.<system>.${name}";
  pkg-link = name: "[`pkgs.${name}`](#${anchor' (pkg-header name)})";

  nixpkgs-link = name: "[`pkgs.${name}`](https://search.nixos.org/packages?channel=unstable&show=${name})";

  libinput-link = page: header: "https://wayland.freedesktop.org/libinput/doc/latest/${page}.html#${anchor header}";

  libinput-doc = page: header: "[${header}](${libinput-link "${page}.html" (anchor header)})";

  make-default = text:
    if length (splitString "\n" text) == 1
    then "- default: `${text}`"
    else ''
      - default:
      ${indent (delimit "```nix" text "```")}
    '';
  make-docs = flip pipe [
    types.submodule
    (m: m.getSubOptions [])
    (traverse [])
    (mapAttrsToList (
      path: opt:
        "<!-- sorting key: ${path} -->\n"
        + (
          if opt.type.name == "docs-override"
          then "${opt.description}"
          else if opt.type.name == "submodule" && opt.description or null == null
          then "<!-- ${showOption opt.loc} -->"
          else
            (concatStringsSep "\n" (
              remove null [
                "## `${showOption opt.loc}`"
                (optionalString (opt.type.description != "submodule") "- type: `${opt.type.description}`${optionalString (opt.type ? nestedTypes.newtype-inner) ", which is a `${opt.type.nestedTypes.newtype-inner.description}`"}")
                (maybe make-default opt.defaultText)
                ""
                (maybe id opt.description or null)
              ]
            ))
        )
    ))
    (concatStringsSep "\n\n")
  ];
in {
  inherit make-docs;
  lib = {
    inherit unstable-note section header fake-option test anchor anchor' link link' module-doc pkg-header pkg-link nixpkgs-link libinput-link libinput-doc link-niri-commit link-niri-release link-stylix-opt;
  };
}
