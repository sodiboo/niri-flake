{
  lib,
  rev,
  kdl,
  settings-fmt,
}:
let
  inherit (settings-fmt) xml;

  toplevel-options-type = lib.types.submoduleWith {
    modules = [ ../settings/toplevel.nix ];
    specialArgs = {
      inherit kdl;
      niri-flake-internal-fmt = xml.fmt;
    };
  };

  describe-type =
    type:
    if type.name == "shorthand" then
      describe-type type.nestedTypes.real
    else if type.name == "nullOr" && type.nestedTypes.elemType.name == "rename" then
      type.description
    # + " (where ${code type.nestedTypes.elemType.description} is a ${describe-type type.nestedTypes.elemType.nestedTypes.real})"
    else if type.name == "nullOr" && type.nestedTypes.elemType.name == "shorthand" then
      describe-type (lib.types.nullOr type.nestedTypes.elemType.nestedTypes.real)
    else
      type.description;

  showOption = map (segment: "<path-segment>${lib.escapeXML segment}</path-segment>");

  render-option =
    traversed-loc: opt:
    assert opt._type or null == "option";
    lib.optional (opt.visible or true != false) [
      "<option>"
      [
        "<loc>"
        (showOption opt.loc)
        "</loc>"
      ]
      [
        "<declarations>"
        (map (
          {
            file,
            line,
            column,
          }:
          [
            "<declaration"
            " file='${lib.escapeXML (lib.strings.removePrefix "${toString ../.}/" (toString file))}'"
            (lib.optional (line != null) [
              " line='${toString line}'"
            ])
            (lib.optional (column != null) [
              " column='${toString column}'"
            ])
            "/>"
          ]
        ) opt.declarationPositions)
        "</declarations>"
      ]
      (lib.optional (opt ? niri-flake-hierarchy) [
        "<hierarchy>"
        (map (item: [
          "<before>"
          (showOption item.loc)
          "</before>"
        ]) opt.niri-flake-hierarchy.before)
        (map (item: [
          "<after>"
          (showOption item.loc)
          "</after>"
        ]) opt.niri-flake-hierarchy.after)
        "</hierarchy>"
      ])
      [
        "<spec>"
        ("<type>${xml.literal (describe-type opt.type)}</type>")
        (lib.optional (opt.defaultText != null) ("<default>${xml.literal opt.defaultText}</default>"))
        "</spec>"
      ]
      (lib.optional (
        opt.description or null != null
      ) "<description>${xml.body opt.description}</description>")
      (
        let
          suboptions = render-options-node traversed-loc (opt.type.getSubOptions opt.loc);
        in
        lib.optional (suboptions != [ ]) [
          "<options>"
          suboptions
          "</options>"
        ]
      )
      "</option>"
    ];

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
    builtins.concatMap (
      { name, opt }:
      if opt ? _type then
        (lib.flatten (
          render-option (traversed-loc ++ [ name ]) (
            opt
            // {
              defaultText =
                opt.defaultText or (if opt ? default then lib.generators.toPretty { } opt.default else null);

              loc = opt.override-loc or lib.id opt.loc;
            }
          )
        ))
      else
        let
          rendered = render-options-node (traversed-loc ++ [ name ]) opt;
        in
        lib.warnIf (rendered != [ ]) "${
          lib.showOption (traversed-loc ++ [ name ])
        } should probably be an option" rendered
    ) options';
in
builtins.toFile "settings.xml" (''
  <?xml version="1.0"?>
  <?xml-stylesheet type="text/xsl" href="settings.xsl"?>
  <options xmlns:html="http://www.w3.org/1999/xhtml" rev="${lib.escapeXML rev}">${
    lib.replaceStrings [ "&#x0a;" ] [ "\n" ] (
      lib.concatStrings (render-options-node [ ] (toplevel-options-type.getSubOptions [ ]))
    )
  }</options>'')
