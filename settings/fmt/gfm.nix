{ lib, fmt }:
let
  body = lib.strings.trimWith { end = true; };

  showOption = lib.concatStringsSep ".";

  indent-except-first-line =
    text:
    let
      lines = lib.splitString "\n" text;
      lines' = [ (builtins.head lines) ] ++ (map (line: "  ${line}") (builtins.tail lines));
    in

    if lines == [ ] then "" else builtins.concatStringsSep "\n" lines';
in
{
  fmt.link-to-setting = loc: "#${fmt.markdown-anchor "`${showOption loc}`"}";

  fmt.bare-link = url: url;
  fmt.masked-link =
    {
      href,
      content,
    }:
    "[${content}](${href})";

  fmt.block-quote =
    content:
    lib.pipe content [
      body
      (lib.splitString "\n")
      (map (s: "> ${s}\n"))
      lib.concatStrings
    ];

  fmt.code = code: "`${code}`";

  fmt.admonition = lib.genAttrs [ "note" "tip" "important" "warning" "caution" ] (
    kind: content:
    fmt.block-quote ''
      [!${kind}]
      ${content}
    ''
  );

  fmt.list = items: ''
    ${lib.concatStringsSep "\n" (map (item: "- ${indent-except-first-line (body item)}") items)}
  '';
  fmt.ordered-list = items: ''
    ${lib.concatStringsSep "\n" (map (item: "1. ${indent-except-first-line (body item)}") items)}
  '';

  fmt.nix-code-block = code: ''
    ```nix
    ${body code}
    ```
  '';

  fmt.em = text: "*${text}*";
  fmt.strong = text: "**${text}**";

  fmt.table =
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

  fmt.kbd = fmt.code;

  fmt.img =
    {
      src,
      title,
      alt,
    }:
    ''
      ![${alt}](${src} "${builtins.replaceStrings [ "\"" ] [ "\\\"" ] title}")
    '';
}
