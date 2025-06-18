{lib, ...}: let
  node = name: args: children:
    lib.foldl (
      self: arg:
        if lib.isAttrs arg
        then self // {properties = self.properties // arg;}
        else self // {arguments = self.arguments ++ [arg];}
    ) {
      inherit name;
      arguments = [];
      properties = {};
      children = lib.toList children;
    } (lib.toList args);

  plain = name: node name [];
  leaf = name: args: node name args [];
  magic-leaf = node-name: {
    ${node-name} = [];
    __functor = self: arg: {
      inherit (self) __functor;
      ${node-name} = self.${node-name} ++ lib.toList arg;
    };
  };
  flag = name: node name [] [];

  serialize.string = lib.flip lib.pipe [
    (lib.escape ["\\" "\""])
    # including newlines will cause the serialized output to contain additional indentation
    # so we escape them
    (lib.replaceStrings ["\n"] ["\\n"])
    (v: "\"${v}\"")
  ];
  serialize.path = serialize.string;
  serialize.int = toString;
  serialize.float = toString;
  serialize.bool = v:
    if v
    then "true"
    else "false";
  serialize.null = lib.const "null";

  serialize.value = v: serialize.${builtins.typeOf v} v;

  # this is not a complete list of valid identifiers
  # but it is good enough for niri
  # if this rejects a valid ident, literally nothing bad happens
  # essentially, this regex boils down to any sequence of letters, numbers or +/-
  # but not something that looks like a number (e.g. 0, -4, +12)
  bare-ident = "[A-Za-z][A-Za-z0-9+-]*|[+-]|[+-][A-Za-z+-][A-Za-z0-9+-]*";
  serialize.ident = v:
    if lib.strings.match bare-ident v != null
    then v
    else serialize.string v;

  serialize.prop = {
    name,
    value,
  }: "${serialize.ident name}=${serialize.value value}";

  prefix-lines = prefix:
    lib.flip lib.pipe [
      (lib.splitString "\n")
      (map (s: "${prefix}${s}"))
      (lib.concatStringsSep "\n")
    ];

  indent = prefix-lines "    ";

  count-lines = lib.flip lib.pipe [
    (lib.splitString "\n")
    lib.length
  ];

  # a common pattern when declaring a config is to have "optional" nodes
  # that only exist if a certain condition is met.
  # without special handling, this would be done with list concatenation
  # and lib.optional, which is ugly and hard to read.
  # it's also not unthinkable that a user might want to declare many nodes
  # in a separate function, and include in the current list.
  # this function makes it easier to declare optional nodes
  # or adding an infix list of nodes by ignoring null nodes, and flattening the result
  # this is completely fine because in this context,
  # nested lists are not meaningful and neither are null nodes.
  transform-nodes = lib.flip lib.pipe [
    lib.flatten
    (lib.remove null)
  ];

  internal-serialize-nodes = lib.flip lib.pipe [
    (map serialize.node)
    (lib.concatStringsSep "\n")
  ];

  serialize.node = {
    name,
    arguments,
    properties,
    children,
  }:
    lib.concatStringsSep " " (lib.flatten [
      (serialize.ident name)
      (map serialize.value arguments)
      (map serialize.prop (lib.attrsToList properties))
      (
        let
          children' = transform-nodes children;
          serialized = internal-serialize-nodes children';
        in
          if lib.length children' == 0
          then []
          else if count-lines serialized == 1
          then "{ ${serialized}; }"
          else "{\n${indent serialized}\n}"
      )
    ]);

  serialize.nodes = lib.flip lib.pipe [
    transform-nodes
    internal-serialize-nodes
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
      default = [];
    };
    options.properties = lib.mkOption {
      type = lib.types.attrsOf kdl-value;
      default = {};
    };
    options.children = lib.mkOption {
      type = kdl-nodes;
      default = [];
    };
  };

  kdl-leaf = lib.mkOptionType {
    name = "kdl-leaf";
    description = "kdl leaf";
    descriptionClass = "noun";
    check = v: let
      leaves = lib.mapAttrsToList leaf (removeAttrs v ["__functor"]);
    in
      lib.isAttrs v && lib.length leaves == 1 && lib.all kdl-node.check leaves;
    merge = loc: defs: removeAttrs (lib.mergeOneOption loc defs) ["__functor"];
  };

  kdl-args = lib.mkOptionType {
    name = "kdl-args";
    description = "kdl arguments";
    descriptionClass = "noun";
    check = v: kdl-leaf.check {inherit v;};
  };

  kdl-nodes =
    (lib.types.oneOf [(lib.types.listOf (lib.types.nullOr kdl-nodes)) kdl-node])
    // {
      name = "kdl-nodes";
      description = "kdl nodes";
      descriptionClass = "noun";
    };

  kdl-document =
    kdl-nodes
    // {
      name = "kdl-document";
      description = "kdl document";
    };
in {
  inherit node plain leaf magic-leaf flag serialize;
  types = {inherit kdl-value kdl-node kdl-nodes kdl-leaf kdl-args kdl-document;};
}
