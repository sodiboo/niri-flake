{lib}:
with lib; let
  node = name: args: children:
    foldl (self: this:
      if isAttrs this
      then
        self
        // {
          props = self.props // this;
        }
      else
        self
        // {
          args = self.args ++ [this];
        }) {
      inherit name;
      children = toList children;
      args = [];
      props = {};
    } (toList args);

  plain = name: node name [];
  leaf = name: args: node name args [];
  flag = name: node name [] [];

  serialize.string = v: "\"${escape ["\\" "\""] (toString v)}\"";
  serialize.path = serialize.string;
  serialize.int = toString;
  serialize.float = toString;
  serialize.bool = v:
    if v
    then "true"
    else "false";
  serialize.null = "null";

  serialize.value = v: serialize.${builtins.typeOf v} v;

  # this is not a complete list of valid identifiers
  # but it is good enough for niri
  # if this rejects a valid ident, literally nothing bad happens
  # essentially, this regex boils down to any sequence of letters, numbers or +/-
  # but not something that looks like a number (e.g. 0, -4, +12)
  bare-ident = "[A-Za-z][A-Za-z0-9+-]*|[+-]|[+-][A-Za-z+-][A-Za-z0-9+-]*";
  serialize.ident = v:
    if strings.match bare-ident v != null
    then v
    else serialize.string v;

  serialize.prop = {
    name,
    value,
  }: "${serialize.ident name}=${serialize.value value}";

  prefix-lines = prefix:
    flip pipe [
      (splitString "\n")
      (map (s: "${prefix}${s}"))
      (concatStringsSep "\n")
    ];

  indent = prefix-lines "    ";

  count-lines = flip pipe [
    (splitString "\n")
    length
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
  transform-nodes = flip pipe [
    flatten
    (filter (n: n != null))
  ];

  internal-serialize-nodes = flip pipe [
    (map serialize.node)
    (concatStringsSep "\n")
  ];

  serialize.node = {
    name,
    args,
    props,
    children,
  }:
    concatStringsSep " " (flatten [
      (serialize.ident name)
      (map serialize.value args)
      (map serialize.prop (attrsToList props))
      (
        let
          children' = transform-nodes children;
          serialized = internal-serialize-nodes children';
        in
          if length children' == 0
          then []
          else if count-lines serialized == 1
          then "{ ${serialized}; }"
          else "{\n${indent serialized}\n}"
      )
    ]);

  serialize.nodes = flip pipe [
    transform-nodes
    internal-serialize-nodes
  ];

  kdl-value = types.nullOr (
    types.oneOf [
      types.str
      types.int
      types.float
      types.bool
    ]
  );

  kdl-node = types.submodule {
    options.name = mkOption {
      type = types.str;
    };
    options.args = mkOption {
      type = types.listOf kdl-value;
      default = [];
    };
    options.props = mkOption {
      type = types.attrsOf kdl-value;
      default = {};
    };
    options.children = mkOption {
      type = kdl-nodes;
      default = [];
    };
  };

  kdl-leaf = mkOptionType {
    name = "kdl-leaf";
    description = "kdl leaf";
    descriptionClass = "noun";
    check = v: let
      leaves = mapAttrsToList leaf v;
    in
      isAttrs v && length leaves == 1 && all kdl-node.check leaves;
  };

  kdl-args = mkOptionType {
    name = "kdl-args";
    description = "kdl arguments";
    descriptionClass = "noun";
    check = v: kdl-leaf.check {inherit v;};
  };

  kdl-nodes =
    (types.oneOf [(types.listOf (types.nullOr kdl-nodes)) kdl-node])
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
  inherit node plain leaf flag serialize;
  types = {inherit kdl-value kdl-node kdl-nodes kdl-leaf kdl-args kdl-document;};
}
