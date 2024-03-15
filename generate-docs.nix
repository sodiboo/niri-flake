{lib}:
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
        else delimit "{" (indent(mapAttrsToList (name: val: "${name} = ${render val};") v)) "}";
      null = "null";
      list =
        if v == []
        then null
        else delimit "[" (indent(map render v)) "]";
      _ = "<${(builtins.typeOf v)}>";
    };

  describe = path: opt:
    {
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

  make-docs = path: v: (
    if (v ? _type && v._type == "option")
    then (describe path v) // (make-docs path (v.type.getSubOptions v.loc))
    else concatMapAttrs (name: make-docs (path ++ [name])) (filterAttrs (name: const (name != "_module")) v)
  );

  maybe = f: v:
    if v != null
    then f v
    else null;

  multiline-default = text:
    if length (splitString "\n" text) == 1
    then "- default: `${text}`"
    else ''
      - default:
      ${indent (delimit "```nix" text "```")}
    '';
in
  flip pipe [
    types.submodule
    (m: m.getSubOptions [])
    (make-docs [])
    (mapAttrsToList (
      path: opt:
        if opt.type.name == "docs-override"
        then "${opt.description}"
        else if opt.type.name == "submodule" && opt.description or null == null
        then "<!-- ${showOption opt.loc} -->"
        else
          (concatStringsSep "\n" (
            filter (v: v != null) [
              "## `${showOption opt.loc}`"
              # "#### `${path}`"
              "- type: `${opt.type.description}`${optionalString (opt.type ? nestedTypes.newtype-inner) ", which is a `${opt.type.nestedTypes.newtype-inner.description}`"}"
              (maybe multiline-default opt.defaultText)
              ""
              (maybe id opt.description or null)
            ]
          ))
    ))
    (concatStringsSep "\n\n")
  ]
