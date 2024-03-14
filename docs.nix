{lib}:
with lib; let
  match = name: cases: cases.${name} or cases._;
  indent = flip pipe [
    (splitString "\n")
    (map (s: "  ${s}"))
    (concatStringsSep "\n")
  ];
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
        else "{\n${indent (concatStringsSep "\n" (mapAttrsToList (name: val: "${name} = ${render val};") v))}\n}";
      null = "null";
      list =
        if v == []
        then null
        else "<list>";
      _ = "<${(builtins.typeOf v)}>";
    };

  describe = opt:
    optionalAttrs (opt.type.name != "submodule") {
      ${showOption opt.loc} =
        opt
        // {
          defaultText =
            opt.defaultText
            or (render opt.default or null);
        };
    };

  make-docs = v: (
    if (v ? _type && v._type == "option")
    then (describe v) // (make-docs (v.type.getSubOptions v.loc))
    else concatMapAttrs (const make-docs) (filterAttrs (name: const (name != "_module")) v)
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
        ```nix
      ${indent text}
        ```
    '';
in
  flip pipe [
    types.submodule
    (m: m.getSubOptions [])
    make-docs
    (mapAttrsToList (
      loc: opt:
        if opt.type.name == "docs-override"
        then "${opt.description}"
        else
          (concatStringsSep "\n" (
            filter (v: v != null) [
              "## `${loc}`"
              "- type: `${opt.type.description}`"
              (maybe multiline-default opt.defaultText)
              ""
              (maybe id opt.description or null)
            ]
          ))
    ))
    (concatStringsSep "\n\n")
  ]
