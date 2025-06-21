{
  inputs,
  lib,
  ...
}:
with lib; let
  showOption = concatStringsSep ".";
  match = name: cases: cases.${name} or cases._;
  indent = entries: "${pipe entries [
    toList
    (concatStringsSep "\n")
    (splitString "\n")
    (map (s: "  ${s}"))
    (concatStringsSep "\n")
  ]}";

  delimit-pretty = start: content: end: concatStringsSep "\n" [start content end];
  delimit-min = start: content: end: concatStrings [start content end];
  display-value = {
    pretty ? true,
    omit-empty-composites ? false,
  }: let
    display-value' = display-value {inherit pretty;};
    indent' =
      if pretty
      then indent
      else id;
    delimit' =
      if pretty
      then delimit-pretty
      else delimit-min;
  in
    v:
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
          then
            if omit-empty-composites
            then null
            else "{}"
          else delimit' "{" (indent' (mapAttrsToList (name: val: "${name} = ${display-value' val};") v)) "}";
        null = "null";
        list =
          if v == []
          then
            if omit-empty-composites
            then null
            else "[]"
          else delimit' "[" (indent' (map display-value' v)) "]";
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
            then display-value {omit-empty-composites = true;} opt.default
            else null
          );
      };
  };

  traverse = path: v: (
    if (v ? _type && v._type == "option")
    then let v' = v // {loc = v.override-loc or id v.loc;}; in (optionalAttrs (v.visible or true != false) (describe path v')) // (optionalAttrs (v.visible or true == true) (traverse path (v.type.getSubOptions v'.loc)))
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

  unstable-enum = values: ''
    > [!important]
    > The following values for this option are not yet available in stable niri:
    >
    ${pipe values [
      (map (display-value {pretty = false;}))
      (map (s: "> - `${s}`"))
      (concatStringsSep "\n")
    ]}
    >
    > If you wish to use one of the mentioned values, you should make sure ${link' "programs.niri.package"} is set to ${pkg-link "niri-unstable"}.
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
  link-niri-release = version: "[`${version}`](https://github.com/YaLTeR/niri/releases/tag/${version})";

  link-stylix-opt = opt: "[`${opt}`](https://danth.github.io/stylix/options/hm.html#${anchor opt})";

  link-this-github = path: "https://github.com/sodiboo/niri-flake/blob/${inputs.self.rev or "main"}/${path}";

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

  libinput-doc = page: header: "[${header}](${libinput-link page header})";

  make-default = text:
    if length (splitString "\n" text) == 1
    then "- default: `${text}`"
    else ''
      - default:
      ${indent (delimit-pretty "```nix" text "```")}
    '';

  nested-newtype = type:
    if type == null
    then null
    else if type.name == "newtype"
    then type
    else
      nested-newtype (
        type.nestedTypes.elemType or null
      );

  describe-type = type:
    match type.name {
      newtype = let
        display' = describe-type type.nestedTypes.display;
        inner' = describe-type type.nestedTypes.inner;
      in
        display' + optionalString (inner' != null) ", which is a ${inner'}";
      shorthand = link' "<${type.description}>";
      _ = match type.description {
        submodule = null;
        _ = let
          type' = nested-newtype type;
          desc = "`${type.description}`";
        in
          if type' != null && type'.nestedTypes.display.name == "shorthand"
          then replaceStrings ["``"] [""] (replaceStrings [type'.nestedTypes.display.description] ["`${describe-type type'.nestedTypes.display}`"] desc)
          else desc;
      };
    };

  make-docs = flip pipe [
    types.submodule
    (m: m.getSubOptions [])
    (traverse [])
    (mapAttrsToList (
      path: opt: (
        if opt.type.name == "docs-override"
        then "${opt.description}"
        else if elem opt.type.name ["record" "submodule"] && opt.description or null == null
        then "<!-- ${showOption opt.loc} -->"
        else
          (concatStringsSep "\n" (
            remove null [
              "## ${opt.override-header or "`${showOption opt.loc}`"}"
              (optionalString (opt.type.description != "submodule")
                "- type: ${describe-type opt.type}")
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
    inherit unstable-note unstable-enum section header fake-option test anchor anchor' link link' module-doc pkg-header pkg-link nixpkgs-link libinput-link libinput-doc link-niri-commit link-niri-release link-stylix-opt link-this-github display-value;
  };
}
