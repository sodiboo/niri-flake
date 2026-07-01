{
  lib,
  ...
}:

let

  # Internal functor to help for migrating functor.wrapped to functor.payload.elemType
  # Note that individual attributes can be overridden if needed.
  elemTypeFunctor =
    name:
    { elemType, ... }@payload:
    {
      inherit name payload;
      wrappedDeprecationMessage = makeWrappedDeprecationMessage payload;
      binOp =
        a: b:
        let
          merged = a.elemType.typeMerge b.elemType.functor;
        in
        if merged == null then null else { elemType = merged; };
    };

  makeWrappedDeprecationMessage =
    payload:
    { loc }:
    lib.warn ''
      The deprecated `${lib.optionalString (loc != null) "type."}functor.wrapped` attribute ${
        lib.optionalString (loc != null) "of the option `${lib.showOption loc}` "
      }is accessed, use `${lib.optionalString (loc != null) "type."}nestedTypes.elemType` instead.
    '' payload.elemType;

  checkDefsForError =
    check: loc: defs:
    let
      invalidDefs = lib.filter (def: !check def.value) defs;
    in
    if invalidDefs != [ ] then
      { message = "Definition values: ${lib.showDefs invalidDefs}"; }
    else
      null;

in

lib.fix (
  partitioned-list-of:

  elemType:
  lib.mkOptionType rec {
    name = "partitioned-list-of";
    description = "partitioned list of ${
      lib.types.optionDescriptionPhrase (class: class == "noun" || class == "composite") elemType
    }";
    descriptionClass = "composite";
    check = {
      __functor = _self: lib.isList;
      isV2MergeCoherent = true;
    };
    merge = {
      __functor =
        self: loc: defs:
        (self.v2 { inherit loc defs; }).value;
      v2 =
        { loc, defs }:
        let
          evals = {
            before = [ ];
            after = [ ];
          }
          // builtins.mapAttrs (_: map (v: builtins.removeAttrs v [ "priority" ])) (
            builtins.groupBy
              (eval: if eval.priority <= lib.modules.defaultOrderPriority then "before" else "after")
              (
                lib.filter (x: x.optionalValue ? value) (
                  lib.concatLists (
                    lib.imap1 (
                      n: def:
                      lib.imap1 (
                        m: def':
                        (
                          lib.mergeDefinitions (loc ++ [ "[definition ${toString n}-entry ${toString m}]" ]) elemType [
                            {
                              inherit (def) file;
                              value = def';
                            }
                          ]
                          // {
                            priority = def.priority or lib.modules.defaultOrderPriority;
                          }
                        )
                      ) def.value
                    ) defs
                  )
                )
              )
          );
        in
        {
          headError = checkDefsForError check loc defs;
          value = builtins.mapAttrs (_: map (x: x.optionalValue.value or x.mergedValue)) evals;
          valueMeta = builtins.mapAttrs (_: map (v: v.checkedAndMerged.valueMeta)) evals;
        };
    };
    emptyValue = {
      value = {
        before = [ ];
        after = [ ];
      };
    };
    getSubOptions = prefix: elemType.getSubOptions (prefix ++ [ "*" ]);
    getSubModules = elemType.getSubModules;
    substSubModules = m: partitioned-list-of (elemType.substSubModules m);
    functor = (elemTypeFunctor name { inherit elemType; }) // {
      type = payload: partitioned-list-of payload.elemType;
    };
    nestedTypes.elemType = elemType;
  }
)
