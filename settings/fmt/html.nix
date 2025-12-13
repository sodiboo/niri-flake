{ lib, fmt }:

let
  showOption = lib.concatStringsSep ".";

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

  body = break-paragraphs;

  literal = lit: builtins.replaceStrings [ "\n" ] [ "<br>" ] (escape-html lit);

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

in
{
  inherit break-paragraphs;
  escape = escape-html;

  fmt.bare-link =
    href:
    fmt.masked-link {
      href = href;
      content = href;
    };

  fmt.masked-link =
    {
      href,
      content,
    }:
    "<a href=\"${href}\">${content}</a>";

  fmt.code = code: "<code>${literal code}</code>";

  fmt.link-to-setting = loc: "#${showOption loc}";

  css.admonitions = lib.mapAttrsToList (
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

  fmt.admonition =
    builtins.mapAttrs
      (
        _: wrap: content:
        wrap (body content)
      )
      (
        lib.mapAttrs (
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
        ) admonitions-template
      );

  fmt.list = items: "<ul>${lib.concatStrings (map (s: "<li>${body s}</li>") items)}</ul>";
  fmt.ordered-list = items: "<ol>${lib.concatStrings (map (s: "<li>${body s}</li>") items)}</ol>";

  fmt.nix-code-block = code: ''
    <pre><code class="block language-nix">${literal code}</code></pre>
  '';

  fmt.em = text: "<em>${text}</em>";
  fmt.strong = text: "<strong>${text}</strong>";

  fmt.table =
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

  fmt.kbd = keys: "<kbd>${escape-html keys}</kbd>";
  # fmt.kbd = fmt.code;

  fmt.img =
    {
      src,
      alt,
      title,
    }:
    "<img src=\"${src}\" alt=\"${builtins.replaceStrings [ "\n" ] [ "  " ] alt}\" title=\"${
      builtins.replaceStrings [ "\"" ] [ "\\\"" ] title
    }\">";
}
