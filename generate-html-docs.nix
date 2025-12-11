{
  inputs,
  lib,
  kdl,
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

  escape-html =
    let
      html-escapes = {
        "\"" = "&quot;";
        "'" = "&apos;";
        "<" = "&lt;";
        ">" = "&gt;";
        "&" = "&amp;";
      };
    in
    builtins.replaceStrings (builtins.attrNames html-escapes) (builtins.attrValues html-escapes);

  html-skeleton = main-generated-content: ''
    <!DOCTYPE html>
    <html lang="en">

    <head>
        <meta charset="UTF-8" />
        <meta name="viewport" content="width=device-width, initial-scale=1.0" />
        <link rel="stylesheet" href="https://sodi.boo/css/pico.blue.min.css" />
        <!-- <link rel="stylesheet" href="style.css" /> -->
        <title>niri-flake settings docs</title>

        <style>${extra-css}</style>
    </head>

    <body>
        <header class="container">
            <nav aria-label="breadcrumb">
                <ul>
                    <li><a href="#">niri-flake</a></li>
                    <li>settings</li>
                </ul>
            </nav>
        </header>


        <main class="container">

    ${main-generated-content}

        </main>
    </body>

    </html>
  '';

  extra-css = ''
    html {
      scroll-behavior: smooth;
    }
    code:not(.block) {
      display: unset;
    }
    a {
      --pico-code-color: var(--pico-color-primary);
    }

    .options {
      padding-left: 1em;
    }

    .option {
      scroll-margin-top: 1em;
    }

    .option-anchor {
      scroll-margin-top: 3.5em;
    }

    .option-link:not(:hover) > .ancestor-path {
      opacity: 50%;
    }

    ${base-colors}
    ${builtins.concatStringsSep "\n" admonitions-css}
  '';

  base-colors = ''
    :root {
      --gray-1: #515c67;
      --gray-2: #414853;
      --gray-3: #32363f;
      --gray-soft: #65758529;
      --indigo-1: #a8b1ff;
      --indigo-2: #5c73e7;
      --indigo-3: #3e63dd;
      --indigo-soft: #646cff29;
      --purple-1: #c8abfa;
      --purple-2: #a879e6;
      --purple-3: #8e5cd9;
      --purple-soft: #9f7aea29;
      --green-1: #3dd68c;
      --green-2: #30a46c;
      --green-3: #298459;
      --green-soft: #10b98129;
      --yellow-1: #f9b44e;
      --yellow-2: #da8b17;
      --yellow-3: #a46a0a;
      --yellow-soft: #eab30829;
      --red-1: #f66f81;
      --red-2: #f14158;
      --red-3: #b62a3c;
      --red-soft: #f43f5e29;
    }
  '';

  admonitions-template = {
    note = {
      title = "Note";
      color = "indigo";
    };
    tip = {
      title = "Tip";
      color = "green";
    };
    important = {
      title = "Important";
      color = "purple";
    };
    warning = {
      title = "Warning";
      color = "yellow";
    };
    caution = {
      title = "Caution";
      color = "red";
    };
  };

  admonitions-components = lib.mapAttrs (
    kind:
    {
      title,
      color,
    }:
    body: ''
      <div class="admonition ${kind}">
      <div class="admonition-title">${title}</div>
      ${body}
      </div>
    ''
  ) admonitions-template;

  admonitions-css = lib.mapAttrsToList (
    kind:
    {
      title,
      color,
    }:
    ''
      .admonition.${kind} {
        border: 1px solid transparent;
        background-color: var(--${color}-soft);
        border-radius: 8px;
        padding: 16px 16px 8px;

        .admonition-title {
          color: var(--${color}-3);
          font-weight: 600;
          margin-bottom: .5em;
        }
      }
    ''
  ) admonitions-template;

  break-paragraphs =
    text:
    lib.pipe text [
      (lib.replaceStrings [ "\\\n" ] [ "" ])
      (lib.splitString "\n\n")
      (lib.remove "\n")
      (lib.remove "")
      (map (s: "<p>${s}</p>"))
      lib.concatStrings
    ];

  describe-type =
    type:
    let
      code = c: "<code>${escape-html c}</code>";
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

  option-component =
    loc:
    {
      open ? false,
      content ? null,
      children,
    }:
    ''
      <details class="option"${lib.optionalString open " open"}>
      <summary>
      <a class="option-link" href="#${showOption loc}">${
        let
          has-ancestor = builtins.length loc > 1;

          nested =
            let
              ancestor-path = escape-html (showOption (lib.lists.dropEnd 1 loc));
              this = escape-html (showOption ([ (lib.lists.last loc) ]));
            in
            ''<span class="ancestor-path">${ancestor-path}.</span>${this}'';

          toplevel = escape-html (showOption loc);
        in
        if has-ancestor then nested else toplevel
      }</a>
      </summary>
      <a id="${showOption loc}" class="option-anchor"></a>
      ${lib.optionalString (content != null) ''
        <div class="option-content">${content}</div>
      ''}
      ${children}
      </details>
    '';

  render-option =
    opt:
    assert opt._type or null == "option";
    lib.optional (opt.visible or true != false) ''
      ${
        option-component opt.loc {
          # open = opt.visible or true == true;
          content = ''
            ${lib.concatStringsSep "\n" [
              (
                let
                  described = describe-type opt.type;
                in
                lib.optionalString (described != "<code>submodule</code>") ''
                  <p>
                  type: ${described}
                  </p>
                ''
              )
              (lib.optionalString (opt.defaultText != null) (''
                <p>
                default: <code>${escape-html opt.defaultText}</code>
                </p>
              ''))
              (lib.optionalString (opt.description or null != null) (''
                ${break-paragraphs opt.description}
              ''))
            ]}
          '';
          children = lib.optionalString (opt.visible or true != false) (
            render-suboptions (expand-suboptions opt.loc (opt.type.getSubOptions opt.loc))
          );
        }

      }
    '';

  render-options-node =
    loc: options:
    assert !(options ? _type);
    expand-suboptions loc options;

  # render-options-node =
  #   loc: options:
  #   assert !(options ? _type);
  # let
  #   suboptions = expand-suboptions loc options;
  # in
  # lib.optional (suboptions != [ ]) ''
  #   ${option-component loc {
  #     children = render-suboptions suboptions;
  #   }}
  # '';

  # (lib.remove "")

  # (
  #   suboptions:
  #   lib.optionalString (suboptions != [ ]) ''
  #     <ul class="options">
  #     ${lib.concatStrings (map (s: "<li>${s}</li>") suboptions)}
  #     </ul>
  #   ''
  # )

  render-suboptions = suboptions: ''
    <ul class="options">
    ${lib.concatStrings (map (s: "<hr><li>${s}</li>") suboptions)}
    </ul>
  '';

  expand-suboptions =
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

            loc = opt.override-loc or lib.id opt.loc;
          }
        )
      else
        render-options-node (loc ++ [ name ]) opt
    ) options';

  make-docs = lib.flip lib.pipe [
    (ty: ty.getSubOptions [ ])
    (expand-suboptions [ ])
    (render-suboptions)
    html-skeleton
  ];
in
{
  inherit make-docs;
  settings-fmt =
    let
      body = break-paragraphs;

      literal = lit: builtins.replaceStrings [ "\n" ] [ "<br>" ] (escape-html lit);
    in
    rec {
      bare-link =
        href:
        masked-link {
          href = href;
          content = href;
        };
      masked-link =
        {
          href,
          content,
        }:
        "<a href=\"${href}\">${content}</a>";

      code = code: "<code>${literal code}</code>";

      link-to-setting = loc: "#${showOption loc}";

      admonition = builtins.mapAttrs (
        _: wrap: content:
        wrap (body content)
      ) admonitions-components;

      list = items: "<ul>${lib.concatStrings (map (s: "<li>${body s}</li>") items)}</ul>";
      ordered-list = items: "<ol>${lib.concatStrings (map (s: "<li>${body s}</li>") items)}</ol>";

      nix-code-block = code: ''
        <pre><code class="block language-nix">${literal code}</code></pre>
      '';

      em = text: "<em>${text}</em>";
      strong = text: "<strong>${text}</strong>";

      table =
        {
          headers,
          align,
          rows,
        }:
        assert (builtins.length headers == builtins.length align);
        let

          align' = map (
            align:
            if align == null then
              ""
            else
              {
                left = " align=\"left\"";
                center = " align=\"center\"";
                right = " align=\"right\"";
              }
              .${align}
          ) align;

          with-align = lib.imap0 (
            i: content: {
              align = builtins.elemAt align' i;
              inherit content;
            }
          );

          header-row = "<tr>${
            lib.concatStrings (
              map (
                {
                  align,
                  content,
                }:
                "<th${align}>${content}</th>"
              ) (with-align headers)
            )
          }</tr>";

          body-rows = map (
            row:
            assert builtins.length headers == builtins.length row;
            "<tr>${
              lib.concatStrings (
                map (
                  {
                    align,
                    content,
                  }:
                  "<td${align}>${content}</td>"
                ) (with-align row)
              )
            }</tr>"
          ) rows;
        in
        "<table><thead>${header-row}</thead><tbody>${lib.concatStrings body-rows}</tbody></table>";

      kbd = keys: "<kbd>${escape-html keys}</kbd>";
      # kbd = code;

      img =
        {
          src,
          alt,
          title,
        }:
        "<img src=\"${src}\" alt=\"${builtins.replaceStrings [ "\n" ] [ "  " ] alt}\" title=\"${
          builtins.replaceStrings [ "\"" ] [ "\\\"" ] title
        }\">";
    };
}
