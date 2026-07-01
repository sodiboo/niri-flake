{ lib, fmt }:
let
  body = lib.flip lib.pipe [
    (lib.replaceStrings [ "\\\n" ] [ "" ])
    (lib.splitString "\n\n")
    (map lib.trim)
    (lib.remove "")
    (map (lib.replaceStrings [ "\n" ] [ " " ]))
    (map (s: if lib.hasPrefix "<" s then s else "<html:p>${s}</html:p>"))
    lib.concatStrings
  ];

  literal = lib.flip lib.pipe [
    (lib.trimWith { end = true; })
    lib.escapeXML
    (lib.replaceStrings [ "\n" ] [ "&#x0a;" ])
  ];

  block = content: "\n\n${content}\n\n";
in
{
  inherit body literal;

  fmt.bare-link = href: ''<html:a href="${literal href}">${literal href}</html:a>'';

  fmt.masked-link =
    {
      href,
      content,
    }:
    ''<html:a href="${literal href}">${content}</html:a>'';

  fmt.code = code: "<html:code>${literal code}</html:code>";

  # fmt.link-to-setting = loc: "#${lib.strings.escapeURL (showOption loc)}";

  fmt.link' =
    loc:
    ''<option-link><path>${
      builtins.concatStringsSep "" (map (segment: "<path-segment>${literal segment}</path-segment>") loc)
    }</path></option-link>'';

  fmt.link-opt =
    opt:
    assert opt._type == "option";
    fmt.link' opt.loc;

  fmt.link-opt-masked =
    opt: text:
    assert opt._type == "option";
    ''<option-link><path>${
      builtins.concatStringsSep "" (
        map (segment: "<path-segment>${literal segment}</path-segment>") opt.loc
      )
    }</path><text>${text}</text></option-link>'';

  fmt.link-opt' = opt: loc: fmt.link-opt-masked opt (fmt.code (lib.showOption loc));

  fmt.admonition = lib.genAttrs [
    "note"
    "tip"
    "important"
    "warning"
    "caution"
  ] (kind: content: block ''<admonition kind="${kind}">${body content}</admonition>'');

  fmt.list =
    items:
    block "<html:ul>${lib.concatStrings (map (s: "<html:li>${body s}</html:li>") items)}</html:ul>";
  fmt.ordered-list =
    items:
    block "<html:ol>${lib.concatStrings (map (s: "<html:li>${body s}</html:li>") items)}</html:ol>";

  fmt.nix-code-block = code: block ''<codeblock lang="nix">${literal code}</codeblock>'';

  fmt.em = text: "<html:em>${text}</html:em>";
  fmt.strong = text: "<html:strong>${text}</html:strong>";

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

      header-row = "<html:tr>${
        lib.concatStrings (
          map (
            {
              align,
              content,
            }:
            "<html:th${align}>${content}</html:th>"
          ) (with-align headers)
        )
      }</html:tr>";

      body-rows = map (
        row:
        assert builtins.length headers == builtins.length row;
        "<html:tr>${
          lib.concatStrings (
            map (
              {
                align,
                content,
              }:
              "<html:td${align}>${content}</html:td>"
            ) (with-align row)
          )
        }</html:tr>"
      ) rows;
    in
    block "<html:table><html:thead>${header-row}</html:thead><html:tbody>${lib.concatStrings body-rows}</html:tbody></html:table>";

  fmt.kbd = keys: "<html:kbd>${literal keys}</html:kbd>";
  # fmt.kbd = fmt.code;

  fmt.img =
    {
      src,
      alt,
      title,
    }:
    block ''<html:img src="${literal src}" alt="${literal alt}" title="${literal title}" />'';
}
