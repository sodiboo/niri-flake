{lib}:
with lib; let
  node = name: args: children: let
    args' = toList args;
    has-props = (length args' != 0) && isAttrs (last args');
  in {
    inherit name children;

    props =
      if has-props
      then last args'
      else {};

    args =
      if has-props
      then take (length args' - 1) args'
      else args';
  };

  plain = name: node name [];
  leaf = name: args: node name args [];
  plain-leaf = name: node name [] [];

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
        if length children == 0
        then []
        else let
          serialized = serialize.nodes children;
        in
          if count-lines serialized == 1
          then "{ ${serialized}; }"
          else "{\n${indent serialized}\n}"
      )
    ]);

  serialize.nodes = flip pipe [
      flatten
      (filter (n: n != null))
      (map serialize.node)
      (concatStringsSep "\n")
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

  kdl-nodes = types.oneOf [(types.listOf (types.nullOr kdl-nodes)) kdl-node];
in {
  inherit node plain plain-leaf leaf serialize;
  types = {inherit kdl-value kdl-node kdl-nodes;};
}
