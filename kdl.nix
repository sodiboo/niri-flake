{ lib, ... }:
let
  fold-args =
    lib.foldl
      (
        self: arg:
        if lib.isAttrs arg then
          self // { properties = self.properties // arg; }
        else
          self // { arguments = self.arguments ++ [ arg ]; }
      )
      {
        arguments = [ ];
        properties = { };
      };
  node = name: args: children: {
    inherit name;
    inherit (fold-args (lib.toList args)) arguments properties;
    inherit children;
  };

  plain = name: node name [ ];
  leaf = name: args: node name args [ ];
  magic-leaf = node-name: {
    ${node-name} = [ ];
    __functor = self: arg: {
      inherit (self) __functor;
      ${node-name} = self.${node-name} ++ lib.toList arg;
    };
  };
  flag = name: node name [ ] [ ];

  serialize.string = lib.flip lib.pipe [
    (lib.escape [
      "\\"
      "\""
    ])
    # including newlines will cause the serialized output to contain additional indentation
    # so we escape them
    (lib.replaceStrings [ "\n" ] [ "\\n" ])
    (v: "\"${v}\"")
  ];
  serialize.path = serialize.string;
  serialize.int = toString;
  serialize.float = toString;
  serialize.bool = v: if v then "true" else "false";
  serialize.null = lib.const "null";

  serialize.value = v: serialize.${builtins.typeOf v} v;

  # this is not a complete list of valid identifiers
  # but it is good enough for niri
  # if this rejects a valid ident, literally nothing bad happens
  # essentially, this regex boils down to any sequence of letters, numbers or +/-
  # but not something that looks like a number (e.g. 0, -4, +12)
  bare-ident = "[A-Za-z][A-Za-z0-9+-]*|[+-]|[+-][A-Za-z+-][A-Za-z0-9+-]*";
  serialize.ident = v: if lib.strings.match bare-ident v != null then v else serialize.string v;

  serialize.prop =
    {
      name,
      value,
    }:
    "${serialize.ident name}=${serialize.value value}";

  single-indent = "    ";

  should-collapse =
    children:
    let
      length = lib.length children;
    in
    length == 0 || (length == 1 && should-collapse (lib.head children).children);

  serialize.node = serialize.node-with "";
  serialize.node-with =
    indent:
    {
      name,
      arguments,
      properties,
      children,
    }:
    indent
    + lib.concatStringsSep " " (
      lib.flatten [
        (serialize.ident name)
        (map serialize.value arguments)
        (map serialize.prop (lib.attrsToList properties))
        (
          if lib.length children == 0 then
            [ ]
          else if should-collapse children then
            "{ ${serialize.nodes children}; }"
          else
            "{\n${serialize.nodes-with (indent + single-indent) children}\n${indent}}"
        )
      ]
    );

  serialize.nodes = serialize.nodes-with "";
  serialize.nodes-with =
    indent:
    lib.flip lib.pipe [
      (map (serialize.node-with indent))
      (lib.concatStringsSep "\n")
    ];

  kdl-value = lib.types.nullOr (
    lib.types.oneOf [
      lib.types.str
      lib.types.int
      lib.types.float
      lib.types.bool
    ]
  );

  kdl-node = lib.types.submodule {
    options.name = lib.mkOption {
      type = lib.types.str;
    };
    options.arguments = lib.mkOption {
      type = lib.types.listOf kdl-value;
      default = [ ];
    };
    options.properties = lib.mkOption {
      type = lib.types.attrsOf kdl-value;
      default = { };
    };
    options.children = lib.mkOption {
      type = kdl-document;
      default = [ ];
    };
  };

  kdl-leaf = lib.mkOptionType {
    name = "kdl-leaf";
    description = "kdl leaf";
    descriptionClass = "noun";
    check =
      v: lib.isAttrs v && lib.length (builtins.attrNames (builtins.removeAttrs v [ "__functor" ])) == 1;
    merge = lib.mergeUniqueOption {
      message = "";
      merge =
        loc: defs:
        let
          def = builtins.head defs;

          name = builtins.head (builtins.attrNames (builtins.removeAttrs def.value [ "__functor" ]));

          args = kdl-args.merge (loc ++ name) [
            {
              inherit (def) file;
              value = def.value.${name};
            }
          ];
        in
        {
          ${name} = args;
        };
    };
  };

  kdl-args =
    let
      arg = lib.types.either (lib.types.attrsOf kdl-value) kdl-value;
      args = lib.types.either (lib.types.listOf arg) arg;
    in
    lib.mkOptionType {
      name = "kdl-args";
      description = "kdl arguments";
      descriptionClass = "noun";

      inherit (lib.types.uniq args) check merge;
    };

  kdl-nodes = lib.types.listOf kdl-node // {
    name = "kdl-nodes";
    description = "kdl nodes";
    descriptionClass = "noun";
  };

  kdl-document = lib.mkOptionType {
    name = "kdl-document";
    description = "kdl document";
    descriptionClass = "noun";

    check = v: builtins.isList v || builtins.isAttrs v;
    merge =
      loc: defs:
      kdl-nodes.merge loc (
        map (def: {
          inherit (def) file;
          value =
            let
              value' = lib.remove null (lib.flatten def.value);
            in
            lib.warnIf (def.value != value')
              "kdl document defined in `${def.file}` for `${lib.showOption loc}` is not normalized. please ensure that it is a flat list of nodes."
              value';
        }) defs
      );
  };
in
{
  inherit
    node
    plain
    leaf
    magic-leaf
    flag
    serialize
    ;
  types = {
    inherit
      kdl-value
      kdl-node
      kdl-nodes
      kdl-leaf
      kdl-args
      kdl-document
      ;
  };
}
