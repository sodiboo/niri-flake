{
  lib,
  config,
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

  alphabetize =
    sections:
    lib.mergeAttrsList (
      lib.imap0 (i: section: {
        ${builtins.elemAt lib.strings.lowerChars i} = section;
      }) sections
    );

  ordered-record = ordered-record' null;

  ordered-record' =
    description: sections:
    types.submoduleWith {
      inherit description;
      shorthandOnlyDefinesConfig = true;
      modules = make-ordered-options sections;
    };

  make-ordered-options =
    sections:
    let
      grouped = lib.groupBy (s: if s ? __module then "module" else "options") sections;

      options' = grouped.options or [ ];
      module' = map (builtins.getAttr "__module") grouped.module or [ ];

      flat-options = lib.mergeAttrsList options';

      real-options = lib.filterAttrs (_: opt: !(opt ? niri-flake-document-internal)) flat-options;

      extra-docs-options = lib.filterAttrs (_: opt: opt ? niri-flake-document-internal) flat-options;
    in
    module'
    ++ [
      {
        options = real-options;
      }
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
            default = builtins.concatMap builtins.attrNames options';
          };

          inherit extra-docs-options;
        };
      }

    ];

  make-section = type: optional type { };

  section' = flip pipe [
    submodule
    make-section
  ];
  section = flip pipe [
    record
    make-section
  ];
  ordered-section = flip pipe [
    ordered-record
    make-section
  ];
in

let
  files =
    map
      (
        f:
        import f {
          inherit
            lib
            kdl
            fragments
            toplevel-options
            ;
          niri-flake-internal = {
            inherit
              fmt
              link-opt
              subopts
              section'
              make-ordered-options
              nullable
              float-or-int
              section
              record
              record'
              ordered-record'
              required
              regex
              list
              attrs
              rename
              shorthand-for
              ordered-section
              docs-only
              attrs-record
              attrs-record'
              optional
              rename-warning
              obsolete-warning
              link-niri-release
              ;
          };
        }
      )
      [
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
      ];

  fragments = lib.mergeAttrsList (builtins.map (f: f.fragments or { }) files);

  sections = builtins.concatMap (f: f.sections or [ ]) files;
in
{
  imports = (make-ordered-options (map (s: s.options) sections));
  options.rendered = lib.mkOption {
    type = kdl.types.kdl-document;
    readOnly = true;
  };
  config.rendered = map (s: (s.render or (_: [ ])) config) sections;
}
