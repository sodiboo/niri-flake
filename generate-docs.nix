{
  inputs,
  lib,
  ...
}:
let
  showOption = lib.concatStringsSep ".";
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
    ${lib.pipe values [
      (map (display-value {
        pretty = false;
      }))
      (map (s: "> - `${s}`"))
      (lib.concatStringsSep "\n")
    ]}
    >
    > If you wish to use one of the mentioned values, you should make sure ${link' "programs.niri.package"} is set to ${pkg-link "niri-unstable"}.
    >
    > Otherwise, your system might fail to build.
  '';

  section =
    contents:
    lib.mkOption {
      type = lib.mkOptionType { name = "docs-override"; };
      description = contents;
    };

  header = title: section "# ${title}";
  fake-option =
    loc: contents:
    section ''
      ## `${loc}`

      ${contents}
    '';

  link-niri-commit =
    {
      rev,
      shortRev,
    }:
    "[`${shortRev}`](https://github.com/YaLTeR/niri/tree/${rev})";
  link-niri-release =
    version: "[`${version}`](https://github.com/YaLTeR/niri/releases/tag/${version})";

  link-stylix-opt = opt: "[`${opt}`](https://danth.github.io/stylix/options/hm.html#${anchor opt})";

  link-this-github =
    path: "https://github.com/sodiboo/niri-flake/blob/${inputs.self.rev or "main"}/${path}";

  test = pat: str: lib.strings.match pat str != null;

  anchor = lib.flip lib.pipe [
    (lib.replaceStrings (lib.upperChars ++ [ " " ]) (lib.lowerChars ++ [ "-" ]))
    (lib.splitString "")
    (lib.filter (test "[a-z0-9-]"))
    lib.concatStrings
  ];
  anchor' = loc: anchor "`${loc}`";

  link = title: "[${title}](#${anchor title})";
  link' = loc: "[`${lib.removePrefix "programs.niri.settings." loc}`](#${anchor "`${loc}`"})";

  module-doc =
    name: desc: opts:
    {
      _ = section ''
        # `${name}`

        ${desc}
      '';
    }
    // opts;

  pkg-header = name: "packages.<system>.${name}";
  pkg-link = name: "[`pkgs.${name}`](#${anchor' (pkg-header name)})";

  nixpkgs-link =
    name: "[`pkgs.${name}`](https://search.nixos.org/packages?channel=unstable&show=${name})";

  libinput-link =
    page: header: "https://wayland.freedesktop.org/libinput/doc/latest/${page}.html#${anchor header}";

  libinput-doc = page: header: "[${header}](${libinput-link page header})";

  make-default =
    text:
    if lib.length (lib.splitString "\n" text) == 1 then
      "- default: `${text}`"
    else
      ''
        - default:
        ${indent (delimit-pretty "```nix" text "```")}
      '';

  nested-newtype =
    type:
    if type == null then
      null
    else if type.name == "newtype" then
      type
    else
      nested-newtype (type.nestedTypes.elemType or null);

  describe-type =
    type:
    match type.name {
      newtype =
        let
          display' = describe-type type.nestedTypes.display;
          inner' = describe-type type.nestedTypes.inner;
        in
        display' + lib.optionalString (inner' != null) ", which is a ${inner'}";
      shorthand = link' "<${type.description}>";
      _ = match type.description {
        submodule = null;
        _ =
          let
            type' = nested-newtype type;
            desc = "`${type.description}`";
          in
          if type' != null && type'.nestedTypes.display.name == "shorthand" then
            lib.replaceStrings [ "``" ] [ "" ] (
              lib.replaceStrings
                [ type'.nestedTypes.display.description ]
                [ "`${describe-type type'.nestedTypes.display}`" ]
                desc
            )
          else
            desc;
      };
    };

  render-option =
    opt:
    assert opt._type or null == "option";
    lib.optional (opt.visible != false) (

      if opt.type.name == "docs-override" then
        "${opt.description}"
      else if opt.type.name == "submodule" && opt.description or null == null then
        "<!-- ${showOption opt.loc} -->"
      else
        lib.concatStringsSep "\n" (
          lib.remove null [
            "## ${opt.override-header or "`${showOption opt.loc}`"}"
            (lib.optionalString (opt.type.description != "submodule") "- type: ${describe-type opt.type}")
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

  make-docs = lib.flip lib.pipe [
    lib.types.submodule
    (m: m.getSubOptions [ ])
    (render-suboptions [ ])
    (lib.concatStringsSep "\n\n")
  ];
in
{
  inherit make-docs;
  lib = {
    inherit
      unstable-note
      unstable-enum
      section
      header
      fake-option
      test
      anchor
      anchor'
      link
      link'
      module-doc
      pkg-header
      pkg-link
      nixpkgs-link
      libinput-link
      libinput-doc
      link-niri-commit
      link-niri-release
      link-stylix-opt
      link-this-github
      display-value
      ;
  };

  settings-fmt =
    let
      body = lib.strings.trimWith { end = true; };

      indent-except-first-line =
        text:
        let
          lines = lib.splitString "\n" text;
          lines' = [ (builtins.head lines) ] ++ (map (line: "  ${line}") (builtins.tail lines));
        in

        if lines == [ ] then "" else builtins.concatStringsSep "\n" lines';
    in
    rec {
      link-to-setting = loc: "#${anchor' "`${loc}`"}";

      bare-link = url: url;
      masked-link =
        {
          href,
          content,
        }:
        "[${content}](${href})";

      block-quote =
        content:
        lib.pipe content [
          body
          (lib.splitString "\n")
          (map (s: "> ${s}"))
          (lib.concatStringsSep "\n")
        ];

      code = code: "`${code}`";

      admonition = lib.genAttrs [ "note" "tip" "important" "warning" "caution" ] (
        kind: content:
        block-quote ''
          [!${kind}]
          ${content}
        ''
      );

      list = items: ''
        ${lib.concatStringsSep "\n" (map (item: "- ${indent-except-first-line (body item)}") items)}
      '';
      ordered-list = items: ''
        ${lib.concatStringsSep "\n" (map (item: "1. ${indent-except-first-line (body item)}") items)}
      '';

      nix-code-block = code: ''
        ```nix
        ${body code}
        ```
      '';

      em = text: "*${text}*";
      strong = text: "**${text}**";

      table =
        {
          headers,
          align,
          rows,
        }:
        assert (builtins.length headers == builtins.length align);
        ''
          | ${builtins.concatStringsSep " | " headers} |
          | ${
            builtins.concatStringsSep " | " (
              map (
                align:
                if align == null then
                  "---"
                else
                  {
                    left = ":---";
                    center = ":---:";
                    right = "---:";
                  }
                  .${align}
              ) align
            )
          } |
          ${lib.concatStringsSep "\n" (
            map (
              row:
              assert builtins.length headers == builtins.length row;
              "| ${builtins.concatStringsSep " | " row} |"
            ) rows
          )}
        '';

      kbd = code;

      img =
        {
          src,
          title,
          alt,
        }:
        ''
          ![${alt}](${src} "${builtins.replaceStrings [ "\"" ] [ "\\\"" ] title}")
        '';
    };
}
