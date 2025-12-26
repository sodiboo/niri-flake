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

  # Copied straight from https://github.com/NixOS/nixpkgs/commit/3cba7bb8d24c6a1e2c303b0a907c7fb5476175dd#diff-eb220a9512b9b2ec8b9d3a526386fbc5e6959f17477df260ece781769672e78d
  nixpkgs-kdl-type =
    let
      mergeUniq =
        mergeOne:
        lib.mergeUniqueOption {
          message = "";
          merge =
            loc: defs:
            let
              inherit (lib.head defs) file value;
            in
            mergeOne file loc value;
        };

      mergeFlat =
        elemType: loc: file: value:
        if value ? _type then
          throw "${lib.showOption loc} has wrong type: expected '${elemType.description}', got `${value._type}`"
        else
          elemType.merge loc [ { inherit file value; } ];

      uniqFlatListOf =
        elemType:
        lib.mkOptionType {
          name = "uniqFlatListOf";
          inherit (lib.types.listOf elemType) description descriptionClass;
          check = lib.isList;
          merge = mergeUniq (
            file: loc: lib.imap1 (i: mergeFlat elemType (loc ++ [ "[entry ${toString i}]" ]) file)
          );
        };

      uniqFlatAttrsOf =
        elemType:
        lib.mkOptionType {
          name = "uniqFlatAttrsOf";
          inherit (lib.types.attrsOf elemType) description descriptionClass;
          check = lib.isAttrs;
          merge = mergeUniq (file: loc: lib.mapAttrs (name: mergeFlat elemType (loc ++ [ name ]) file));
        };

      kdlUntypedValue = lib.mkOptionType {
        name = "kdlUntypedValue";
        description = "KDL value without type annotation";
        descriptionClass = "noun";

        inherit
          (lib.types.nullOr (
            lib.types.oneOf [
              lib.types.str
              lib.types.bool
              lib.types.number
              lib.types.path
            ]
          ))
          check
          merge
          ;
      };

      kdlTypedValue = lib.mkOptionType {
        name = "kdlTypedValue";
        description = "KDL value with type annotation";
        descriptionClass = "noun";

        check = lib.isAttrs;
        merge =
          let
            base = lib.types.submodule {
              options = {
                type = lib.mkOption {
                  type = lib.types.nullOr lib.types.str;
                  default = null;
                  description = ''
                    [Type annotation](https://kdl.dev/spec/#name-type-annotation) of a [KDL value](https://kdl.dev/spec/#name-value).
                  '';
                };
                value = lib.mkOption {
                  type = kdlUntypedValue;
                  description = ''
                    Scalar part of a [KDL value](https://kdl.dev/spec/#name-value)
                  '';
                };
              };
            };
          in
          loc: defs: base.merge loc defs;
      };

      # https://kdl.dev/spec/#name-value
      kdlValue =

        let
          base = lib.types.coercedTo kdlUntypedValue (value: { inherit value; }) kdlTypedValue;
        in

        lib.mkOptionType {
          name = "kdlValue";
          description = "KDL value";
          descriptionClass = "noun";

          check = v: base.check v;
          merge = loc: defs: base.merge loc defs;

          nestedTypes = {
            type = lib.types.nullOr lib.types.str;
            scalar = kdlUntypedValue;
          };
        };

      # https://kdl.dev/spec/#name-node
      kdlNode = lib.mkOptionType {
        name = "kdlNode";
        description = "KDL node";
        descriptionClass = "noun";

        check = lib.isAttrs;
        merge =
          let
            base = lib.types.submodule {
              options = {
                type = lib.mkOption {
                  type = lib.types.nullOr lib.types.str;
                  default = null;
                  description = ''
                    [Type annotation](https://kdl.dev/spec/#name-type-annotation) of a KDL node.
                  '';
                };
                name = lib.mkOption {
                  type = lib.types.str;
                  description = ''
                    Name of a [KDL node](https://kdl.dev/spec/#name-node).
                  '';
                };
                arguments = lib.mkOption {
                  type = uniqFlatListOf kdlValue;
                  default = [ ];
                  description = ''
                    [Arguments](https://kdl.dev/spec/#name-argument) of a KDL node.
                  '';
                };
                properties = lib.mkOption {
                  type = uniqFlatAttrsOf kdlValue;
                  default = { };
                  description = ''
                    [Properties](https://kdl.dev/spec/#name-property) of a KDL node.
                  '';
                };
                children = lib.mkOption {
                  type = kdlDocument;
                  default = [ ];
                  description = ''
                    [Children](https://kdl.dev/spec/#children-block) of a KDL node.
                  '';
                };
              };
            };
          in
          loc: defs: base.merge loc defs;

        nestedTypes = {
          name = lib.types.str;
          type = lib.types.nullOr lib.types.str;
          value = kdlValue;
          arguments = uniqFlatListOf kdlValue;
          properties = uniqFlatAttrsOf kdlValue;
          children = kdlDocument;
        };
      };

      kdlDocument = lib.mkOptionType {
        name = "kdlDocument";
        description = "KDL document";
        descriptionClass = "noun";

        check = lib.isList;
        merge = mergeUniq (
          file:
          let
            mergeDocument =
              loc: toplevel:
              builtins.concatLists (
                lib.imap1 (i: mergeDocumentEntry (loc ++ [ "[entry ${toString i}]" ])) toplevel
              );

            mergeDocumentEntry =
              loc: value:
              let
                inherit (lib.options) showDefs;
                defs = [ { inherit file value; } ];
              in
              if lib.isList value then
                mergeDocument loc value
              else if value ? _type then
                if value._type == "if" then
                  if lib.isBool value.condition then
                    if value.condition then mergeDocumentEntry loc value.content else [ ]
                  else
                    throw "`mkIf` called with non-Boolean condition at ${lib.showOption loc}. Definition value:${showDefs defs}"
                else if value._type == "merge" then
                  throw ''
                    ${lib.showOption loc} has wrong type: expected a KDL node or document, got 'merge'.
                    note: `mkMerge` is potentially ambiguous in a KDL document, as "merging" is application-specific. if you intended to "splat" all the nodes in a KDL document, you can just insert the list of nodes directly. you can arbitrarily nest KDL documents, and they will be concatenated.
                  ''
                else
                  throw "${lib.showOption loc} has wrong type: expected a KDL node or document, got '${value._type}'. Definition value:${showDefs defs}"
              else if kdlNode.check value then
                [ (kdlNode.merge loc [ { inherit file value; } ]) ]
              else
                throw "${lib.showOption loc} has wrong type: expected a KDL node or document. Definition value:${showDefs defs}";
          in
          mergeDocument
        );

        nestedTypes.node = kdlNode;
      };
    in
    kdlDocument;

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

  kdl-value = nixpkgs-kdl-type.nestedTypes.node.nestedTypes.value.nestedTypes.scalar;

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

  prune-empty-children = map (
    node:
    let
      children = prune-empty-children node.children;
    in
    if children == [ ] then builtins.removeAttrs node [ "children" ] else node // { inherit children; }
  );

  generator =
    {
      runCommand,
      jsonkdl,
      version ? 1,
      name ? "config.kdl",
      document,
    }:
    assert version == 1 || version == 2;
    runCommand name
      {
        nativeBuildInputs = [ jsonkdl ];
        document = builtins.toJSON (prune-empty-children document);
        passAsFile = [ "document" ];
      }
      ''
        jsonkdl --kdl-v${builtins.toString version} -- "$documentPath" "$out"
      '';
in
{
  inherit
    node
    plain
    leaf
    magic-leaf
    flag
    ;
  serialize = builtins.throw "`kdl.serialize` is gone. replaced with `kdl.generator`.";
  type = nixpkgs-kdl-type;
  generator = generator;
  types = {
    kdl-document = nixpkgs-kdl-type;
    kdl-nodes = nixpkgs-kdl-type;
    kdl-node = nixpkgs-kdl-type.nestedTypes.node;
    inherit
      kdl-value
      kdl-leaf
      kdl-args
      ;
  };
}
