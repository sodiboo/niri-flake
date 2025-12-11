{
  lib,
  options,

  kdl,
  niri-flake-internal-fmt,
  ...
}:
let
  toplevel-options = options;
  fmt = niri-flake-internal-fmt;
  inherit (lib)
    flip
    pipe
    showOption
    mkOption
    mkOptionType
    types
    ;
  inherit (lib.types)
    nullOr
    attrsOf
    listOf
    submodule
    ;

  # binds-stable = binds "${inputs.niri-stable}/niri-config/src/binds.rs";
  # binds-unstable = binds "${inputs.niri-unstable}/niri-config/src/binds.rs";

  record = record' null;

  record' =
    description: options:
    types.submoduleWith {
      inherit description;
      shorthandOnlyDefinesConfig = true;
      modules = [
        { inherit options; }
      ];
    };

  required = type: mkOption { inherit type; };
  nullable = type: optional (nullOr type) null;
  optional = type: default: mkOption { inherit type default; };
  readonly = type: value: optional type value // { readOnly = true; };
  docs-only =
    type:
    required (type // { check = _: true; })
    // {
      internal = true;
      visible = false;
      readOnly = true;
      apply = _: null;
      niri-flake-document-internal = true;
    };

  attrs = type: optional (attrsOf type) { };
  list = type: optional (listOf type) [ ];

  attrs-record = attrs-record' null;

  attrs-record' =
    description: opts:
    attrs (
      if builtins.isFunction opts then
        types.submoduleWith {
          inherit description;
          shorthandOnlyDefinesConfig = true;
          modules = [
            (
              { name, ... }:
              {
                options = opts name;
              }
            )
          ];
        }
      else
        record' description opts
    );

  float-or-int = types.either types.float types.int;

  obsolete-warning = from: to: defs: ''
    ${from} is obsolete.
    Use ${to} instead.
    ${builtins.concatStringsSep "\n" (map (def: "- defined in ${def.file}") defs)}
  '';

  rename-warning = from: to: obsolete-warning (showOption from) (showOption to);

  link-niri-release =
    version:
    fmt.masked-link {
      href = "https://github.com/YaLTeR/niri/releases/tag/${version}";
      content = fmt.code version;
    };

  link' =
    loc:
    fmt.masked-link {
      href = fmt.link-to-setting loc;
      content = fmt.code (lib.removePrefix "programs.niri.settings." (lib.showOption loc));
    };

  subopts =
    opt:
    assert opt._type == "option";
    opt.type.getSubOptions opt.loc;
  link-opt =
    opt:
    assert opt._type == "option";
    link' opt.loc;

  unstable-note = fmt.admonition.important ''
    This option is not yet available in stable niri.

    If you wish to modify this option, you should make sure you're using the latest unstable niri.

    Otherwise, your system might fail to build.
  '';

  shorthand-for =
    type-name: real:
    mkOptionType {
      name = "shorthand";
      description = "<${type-name}>";
      descriptionClass = "noun";
      inherit (real) check merge getSubOptions;
      nestedTypes = { inherit real; };
    };

  rename =
    name: real:
    mkOptionType {
      name = "rename";
      description = "${name}";
      descriptionClass = "noun";
      inherit (real) check merge getSubOptions;
      nestedTypes = { inherit real; };
    };

  regex = rename "regular expression" types.str;

  make-ordered-options =
    {
      finalize ? _: { },
    }:
    sections:

    { options, ... }:
    let
      sections' =
        let
          expand-imports =
            { file, mod }:
            if lib.isList mod then
              builtins.concatMap (mod: expand-imports { inherit file mod; }) mod
            else if lib.isFunction mod then
              expand-imports {
                inherit file;
                mod = mod { inherit options; };
              }
            else if mod ? _file then
              builtins.concatMap (
                mod':
                expand-imports {
                  file = mod._file;
                  mod = mod';
                }
              ) mod.imports
            else
              [ { inherit file mod; } ];
        in
        builtins.concatMap (
          mod:
          expand-imports {
            file = null;
            inherit mod;
          }
        ) sections;
    in
    {
      options._module.niri-flake-ordered-record = {
        ordering = lib.mkOption {
          internal = true;
          # readOnly = true;
          visible = false;
          description = ''
            Used to influence the order of options in the documentation, such that they are not always sorted alphabetically.

            Does not affect any other functionality.
          '';
          default = builtins.concatMap (s: builtins.attrNames s.mod.options) sections';
        };
      };

      imports =
        map (
          s:
          let
            annotate-location = if s.file != null then lib.setDefaultModuleLocation s.file else lib.id;
          in
          annotate-location {
            imports = [
              {
                imports = s.mod.extra-modules or [ ];
                options = lib.filterAttrs (_: opt: !(opt ? niri-flake-document-internal)) s.mod.options;
              }
              {
                options._module.niri-flake-ordered-record.extra-docs-options = lib.filterAttrs (
                  _: opt: opt ? niri-flake-document-internal
                ) s.mod.options;
              }
            ];
          }
        ) sections'
        ++ [
          (
            { config, ... }:
            {
              imports = [ (finalize (map (s: s.mod.render config) sections')) ];
            }
          )
        ];
    };

  make-rendered-options =
    node-name:
    {
      partial,
    }:
    make-ordered-options {
      finalize =
        rendered:
        { config, ... }:
        {
          options.rendered = lib.mkOption (
            {
              type = kdl.types.kdl-node;
              readOnly = true;
              internal = true;
              visible = false;
            }
            // lib.optionalAttrs partial {
              apply = node: lib.mkIf (node.children != [ ]) node;
            }
          );

          config.rendered = kdl.plain node-name [ rendered ];
        };
    };

  make-rendered-section =
    section-name:
    {
      description ? null,
      partial,
    }:
    sections:
    lib.mkOption {
      inherit description;
      default = { };
      type = lib.types.submodule (make-rendered-options section-name { inherit partial; } sections);
    };

  make-section = type: optional type { };

  section' = flip pipe [
    submodule
    make-section
  ];
  section = flip pipe [
    record
    make-section
  ];

  args = {
    inherit
      lib
      kdl
      toplevel-options
      ;
    niri-flake-internal = {
      inherit
        fmt
        link-opt
        subopts
        make-ordered-options
        make-rendered-options
        make-rendered-section
        nullable
        float-or-int
        record
        section
        record'
        section'
        required
        regex
        list
        attrs
        rename
        shorthand-for
        docs-only
        attrs-record
        attrs-record'
        optional
        rename-warning
        obsolete-warning
        link-niri-release
        ;
    };
    appearance = import ./appearance args;
    interactions = import ./interactions args;
  };
in
{
  imports = [
    (make-ordered-options
      {
        finalize = rendered: {
          options.rendered = lib.mkOption {
            type = kdl.types.kdl-document;
            readOnly = true;
          };
          config.rendered = rendered;
        };
      }
      (
        map (f: lib.setDefaultModuleLocation f (import f args)) [
          ./input.nix
          ./outputs.nix
          ./binds.nix
          ./switch-events.nix
          ./layout.nix
          ./overview.nix

          ./workspaces.nix

          ./misc.nix

          ./surface-rules.nix
          ./animations.nix
          ./gestures.nix

          ./debug.nix
        ]
      )
    )
  ];
}
