{
  lib,
  kdl,
  settings-fmt,
}:
let
  inherit (settings-fmt) html;

  toplevel-options-type = lib.types.submoduleWith {
    modules = [ ../settings/toplevel.nix ];
    specialArgs = {
      inherit kdl;
      niri-flake-internal-fmt = html.fmt;
    };
  };

  showOption = lib.concatStringsSep ".";
  display-path-segments =
    loc:
    builtins.concatStringsSep "." (
      map (segment: "<path-segment>${html.escape segment}</path-segment>") loc
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

  html-skeleton = main-generated-content: ''
    <!DOCTYPE html>
    <html lang="en">

    <head>
        <meta charset="UTF-8" />
        <meta name="viewport" content="width=device-width, initial-scale=1.0" />
        <meta name="color-scheme" content="dark light" />
        <link rel=stylesheet href="/settings.css" />
        <title>niri-flake settings</title>

        <script defer src="settings.js"></script>
    </head>

    <body>
        <header>
        <nav aria-label=breadcrumb>${
          builtins.concatStringsSep "" [
            "<ul>"
            ''<li><a href="/">niri-flake</a></li>''
            ''<li><a href="#" aria-current=page>settings</a></li>''
            "</ul>"
          ]
        }</nav>
        </header>

        <hr>


        <main>

    ${main-generated-content}

        </main>
    </body>

    </html>
  '';

  describe-type =
    type:
    let
      code = html.escape; # c: "<code>${html.escape c}</code>";
    in
    if type.name == "rename" then
      (code type.description) + ", which is a ${describe-type type.nestedTypes.real}"
    else if type.name == "shorthand" then
      describe-type type.nestedTypes.real
    else if type.name == "nullOr" && type.nestedTypes.elemType.name == "rename" then
      code type.description
      + " (where ${code type.nestedTypes.elemType.description} is a ${describe-type type.nestedTypes.elemType.nestedTypes.real})"
    else if type.name == "nullOr" && type.nestedTypes.elemType.name == "shorthand" then
      describe-type (lib.types.nullOr type.nestedTypes.elemType.nestedTypes.real)
    else
      code type.description;

  render-options-section =
    traversed-loc: options:
    let
      items = render-options-node traversed-loc options;
    in
    lib.optionalString (items != "") ''
      <ul class=options>${items}</ul>
    '';

  render-option =
    traversed-loc: opt:
    assert opt._type or null == "option";
    lib.optionalString (opt.visible or true != false) (
      let
        # a "section" option is equivalent to a plain option node.
        # a submodule always contains suboptions.
        is-section = opt.type.name == "submodule" && opt.default or null == { };

        open = false; # is-section || suboptions == "";

        content = body: lib.optionalString (body != "") "<option-content>${body}</option-content>";

        component = ''
          <details class=option${lib.optionalString open " open"}>
          <summary>${name}</summary>${anchor}${
            builtins.concatStringsSep "" (
              map
                (lib.flip lib.pipe [
                  (lib.remove "")
                  (builtins.concatStringsSep "")
                  content
                ])
                [
                  [ declaration ]
                  [
                    before
                    after
                  ]
                  [
                    (type {
                      rich = true;
                      wrap = type: "<dt>type</dt><dd><option-type>${type}</option-type></dd>";
                    })
                    (default {
                      wrap = default: "<dt>default</dt><dd><option-default>${default}</option-default></dd>";
                    })
                  ]
                  [ description ]
                ]
            )
          }${suboptions}</details>
        '';

        hierarchy-part =
          {
            area,
            label,
            items,
          }:
          lib.optionalString (items != [ ])
            ''<dt>${label}</dt>${
              builtins.concatStringsSep "" (
                map (item: ''
                  <dd><a href="#${lib.showOption item.loc}">
                  ${html.escape (lib.showOption item.loc)}
                  </a></dd>'') items
              )
            }'';

        declaration = lib.optionalString (opt.declarationPositions != [ ]) (
          let
            link =
              pos: content:
              let
                file = lib.strings.removePrefix "${toString ../.}/" (toString pos.file);
                base = html.fmt.link-this-github file;
                href =
                  if pos.line != null then
                    "${base}#L${toString pos.line}"
                  else
                    lib.warn "${lib.showOption opt.loc} has no position data for declaration in ${pos.file}" base;
              in
              ''<a target="_blank" href="${href}">${content file}</a>'';

            many-declarations = "<dt>declarations</dt>${
              builtins.concatStringsSep "" (
                map (pos: "<dd>${link pos html.escape}</dd>") opt.declarationPositions
              )
            }";
          in

          if builtins.length opt.declarationPositions == 1 then
            many-declarations
          else
            builtins.trace "${lib.showOption opt.loc} has >1 declaration?" many-declarations
        );

        before = hierarchy-part {
          area = "before";
          label = if is-section then "refines" else "overrides";
          items = opt.niri-flake-hierarchy.before or [ ];
        };

        after = hierarchy-part {
          area = "after";
          label = if is-section then "refined by" else "overridden by";
          items = opt.niri-flake-hierarchy.after or [ ];
        };

        name = ''<option-name><a href="#${showOption opt.loc}">${
          let
            has-ancestor = builtins.length opt.loc > 1;

            nested =
              let
                ancestor-path = lib.lists.dropEnd 1 opt.loc;
                this = lib.lists.last opt.loc;
              in
              ''<ancestor-path>${display-path-segments ancestor-path}.</ancestor-path>${display-path-segments [ this ]}'';

            toplevel = display-path-segments opt.loc;
          in
          if has-ancestor then nested else toplevel
        }</a></option-name>'';
        anchor = ''<a class="option-anchor" id="${showOption opt.loc}"></a>'';

        type =
          {
            wrap ? lib.id,
          }:
          let
            described = describe-type opt.type;
          in
          lib.optionalString (described != "submodule") (wrap described);

        default =
          {
            wrap ? lib.id,
          }:
          lib.optionalString (opt.defaultText != null) (wrap (html.escape opt.defaultText));

        description = lib.optionalString (
          opt.description or null != null
        ) ''${html.break-paragraphs opt.description}'';

        suboptions = lib.optionalString (opt.visible or true != false) (
          render-options-section traversed-loc (opt.type.getSubOptions opt.loc)
        );
      in
      component
    );

  render-options-node =
    traversed-loc: options:
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
    builtins.concatStringsSep "" (
      map (
        { name, opt }:
        if opt ? _type then
          render-option (traversed-loc ++ [ name ]) (
            opt
            // {
              defaultText =
                opt.defaultText
                  or (if opt ? default then display-value { omit-empty-composites = true; } opt.default else null);

              loc = opt.override-loc or lib.id opt.loc;
            }
          )
        else
          let
            rendered = render-options-node (traversed-loc ++ [ name ]) opt;
          in
          lib.warnIf (rendered != "") "${
            lib.showOption (traversed-loc ++ [ name ])
          } should probably be an option" rendered
      ) options'
    );
in
builtins.toFile "settings.html" (
  html-skeleton (render-options-section [ ] (toplevel-options-type.getSubOptions [ ]))
)
