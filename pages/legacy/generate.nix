{
  inputs,
  lib,
  kdl,
  fmt-date,
  fmt-time,
  settings-fmt,
}:
let
  inherit (settings-fmt) gfm;

  toplevel-options-type = lib.types.submodule (
    import ./content.nix {
      inherit
        inputs
        lib
        kdl
        fmt-date
        fmt-time
        ;
      inherit (gfm) fmt;
    }
  );

  match = name: cases: cases.${name} or cases._;
  indent =
    entries:
    "${lib.pipe entries [
      lib.toList
      (lib.concatStringsSep "\n")
      (lib.splitString "\n")
      (map (s: "  ${s}"))
      (lib.concatStringsSep "\n")
    ]}";

  delimit-pretty =
    start: content: end:
    lib.concatStringsSep "\n" [
      start
      content
      end
    ];
  delimit-min =
    start: content: end:
    lib.concatStrings [
      start
      content
      end
    ];
  display-value =
    {
      pretty ? true,
      omit-empty-composites ? false,
    }:
    let
      display-value' = display-value { inherit pretty; };
      indent' = if pretty then indent else lib.id;
      delimit' = if pretty then delimit-pretty else delimit-min;
    in
    v:
    match (builtins.typeOf v) {
      string = lib.strings.escapeNixString v;
      int = toString v;
      float = toString v;
      bool = if v then "true" else "false";
      set =
        if v == { } then
          if omit-empty-composites then null else "{}"
        else
          delimit' "{" (indent' (lib.mapAttrsToList (name: val: "${name} = ${display-value' val};") v)) "}";
      null = "null";
      list =
        if v == [ ] then
          if omit-empty-composites then null else "[]"
        else
          delimit' "[" (indent' (map display-value' v)) "]";
      _ = "<${(builtins.typeOf v)}>";
    };

  maybe = f: v: if v != null then f v else null;

  make-default =
    text:
    if lib.length (lib.splitString "\n" text) == 1 then
      "- default: `${text}`"
    else
      ''
        - default:
        ${indent (delimit-pretty "```nix" text "```")}
      '';

  describe-type =
    type:
    let
      span = content: "`${content}`";
    in
    if type.name == "rename" then
      (span type.description) + ", which is a ${describe-type type.nestedTypes.real}"
    else if type.name == "shorthand" then
      gfm.fmt.link' [ "${type.description}" ]
    else if type.name == "nullOr" && type.nestedTypes.elemType.name == "rename" then
      span type.description
      + " (where ${span type.nestedTypes.elemType.description} is a ${describe-type type.nestedTypes.elemType.nestedTypes.real})"
    else if type.name == "nullOr" && type.nestedTypes.elemType.name == "shorthand" then
      span "null or" + gfm.fmt.link' [ "${type.nestedTypes.elemType.description}" ]
    else
      span type.description;

  describe-type' = type: lib.replaceStrings [ "``" ] [ "" ] (describe-type type);

  render-option =
    opt:
    assert opt._type or null == "option";
    lib.optional (opt.visible != false) (

      if opt.type.name == "docs-override" then
        "${opt.description}"
      else if opt.type.name == "submodule" && opt.description or null == null then
        "<!-- ${lib.showOption opt.loc} -->"
      else
        lib.concatStringsSep "\n" (
          lib.remove null [
            "## ${opt.override-header or "`${lib.showOption opt.loc}`"}"
            (
              let
                described = describe-type' opt.type;
              in
              lib.optionalString (described != "`submodule`") "- type: ${described}"
            )
            (maybe make-default opt.defaultText)
            ""
            (maybe lib.id opt.description or null)
          ]
        )
    )
    ++ lib.optionals (opt.visible == true) (render-suboptions opt.loc (opt.type.getSubOptions opt.loc));

  render-suboptions =
    loc: options:
    assert !(options ? _type);
    let
      to-list = lib.mapAttrsToList (name: opt: { inherit name opt; });

      options' =
        if options ? _module.niri-flake-ordered-record then
          let
            ord-record = options._module.niri-flake-ordered-record;
            ordering = ord-record.ordering.value;
            extra-docs-options = ord-record.extra-docs-options;

            ordering' = builtins.listToAttrs (
              lib.imap0 (i: v: {
                name = v;
                value = i;
              }) ordering
            );
            max-ordering = builtins.length ordering;
          in
          builtins.sort (
            a: b: (ordering'.${a.name} or max-ordering) < (ordering'.${b.name} or max-ordering)
          ) (to-list (builtins.removeAttrs (options // extra-docs-options) [ "_module" ]))
        else
          to-list (builtins.removeAttrs options [ "_module" ]);

    in
    builtins.concatMap (
      { name, opt }:
      if opt ? _type then
        render-option (
          opt
          // {
            defaultText =
              opt.defaultText
                or (if opt ? default then display-value { omit-empty-composites = true; } opt.default else null);
            visible = if opt.niri-flake-document-internal or false then true else opt.visible or true;
            loc = opt.override-loc or lib.id opt.loc;
          }
        )
      else
        render-suboptions (loc ++ [ name ]) opt
    ) options';
in
lib.pipe toplevel-options-type [
  (m: m.getSubOptions [ ])
  (render-suboptions [ ])
  (lib.concatStringsSep "\n\n")
]
