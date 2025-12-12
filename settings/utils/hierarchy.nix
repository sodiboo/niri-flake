{
  lib,
  niri-flake-internal,
  ...
}:

let
  inherit (niri-flake-internal)
    fmt
    link-opt
    subopts
    make-rendered-section
    ;

  wrap-description =
    {
      before-label,
      before,
      after-label,
      after,
      description,
    }:
    ''
      ${lib.optionalString (before != [ ]) ''
        ${before-label}:
        ${fmt.list (builtins.map link-opt before)}
      ''}

      ${lib.optionalString (after != [ ]) ''
        ${after-label}:
        ${fmt.list (builtins.map link-opt after)}
      ''}

      ${description}
    '';

  tree = {
    node =
      name:
      {
        options,
        children ? [ ],
      }:
      {
        inherit name options children;
      };
    map =
      f:
      builtins.map (node: {
        inherit (node) name;
        options = f node.options;
        children = tree.map f node.children;
      });
    contains =
      targets:
      builtins.any (node: builtins.elem node.name targets || tree.contains targets node.children);
    find =
      target:
      builtins.foldl' (
        acc: node:
        if acc != null then
          acc
        else if node.name == target then
          node // { ancestors = [ ]; }
        else
          let
            child = tree.find target node.children;
          in
          if child != null then
            child
            // {
              ancestors = [ (builtins.removeAttrs node [ "children" ]) ] ++ child.ancestors;
            }
          else
            null
      ) null;
    walk =
      f:
      lib.fix (
        walk': ancestors:
        builtins.concatMap (
          node: [ (f ancestors node) ] ++ walk' (ancestors ++ [ node.name ]) node.children
        )
      ) [ ];
    retain =
      extent:
      builtins.concatMap (
        node:
        let
          node' = node // {
            children = tree.retain extent node.children;
          };
        in
        if builtins.elem node.name extent || node'.children != [ ] then [ node' ] else [ ]
      );
  };

  make-hierarchical-options =
    {
      hierarchy,
      scope,
      position,
    }:
    let
      this = tree.find position hierarchy;
    in
    assert this != null;
    assert tree.contains scope [ this ];
    lib.fix (
      ctx:
      {
        inherit scope;
        inherit position;

        before = map (ancestor: ancestor.options) this.ancestors;
        options = this.options;
        after = tree.walk (_: child: child.options) (tree.retain scope this.children);

        map =
          f:
          make-hierarchical-options {
            hierarchy = tree.map f hierarchy;
            inherit scope position;
          };
      }
      // lib.mergeAttrsList (
        tree.walk (
          ancestors: target:
          let
            is-target-level = target.name == position;
            is-at-least-target-level = is-target-level || tree.contains [ position ] target.children;
            is-at-most-target-level = is-target-level || builtins.elem position ancestors;
            rescope-if =
              condition: ctx:
              if tree.contains scope [ target ] then
                if condition then f: f ctx else lib.const [ ]
              else
                throw "cannot add ${target}-level options in a ${builtins.concatStringsSep "/" scope}-level context";
          in
          {
            "is-${target.name}-level" = is-target-level;
            "is-at-least-${target.name}-level" = is-at-least-target-level;
            "is-at-most-${target.name}-level" = is-at-most-target-level;

            "${target.name}-level" = rescope-if is-at-most-target-level (make-hierarchical-options {
              inherit hierarchy position;
              scope = [ target.name ];
            });

            "detach-${target.name}-level" = rescope-if is-at-least-target-level (make-hierarchical-options {
              hierarchy = [ target ];
              scope = builtins.filter (s: tree.contains [ s ] [ target ]) scope;
              inherit position;
            });
          }
        ) hierarchy
      )
      // {
        mkOption =
          name:
          {
            description ? "",
            ...
          }@args:
          lib.mkOption (
            args
            // {
              description = wrap-description {
                before-label = "overrides";
                after-label = "overridden by";
                inherit (ctx.map (options: options.${name})) before after;
                inherit description;
              };
            }
          );

        nullable =
          name:
          {
            type,
            default ? null,
            ...
          }@args:
          ctx.mkOption name (
            args
            // {
              inherit default;
              type = lib.types.nullOr type;
            }
          );

        rendered-section =
          name:
          {
            partial,
            description ? "",
          }:
          f:
          let
            ctx' = ctx.map (options: options.${name});
          in
          make-rendered-section name {
            inherit partial;
            description = wrap-description {
              before-label = "refines";
              after-label = "refined by";
              inherit (ctx') before after;
              inherit description;
            };
          } (f (ctx'.map subopts));

        contextual = choices: choices.${ctx.position};
        link-opt-contextual = choices: link-opt choices.${ctx.position};
      }
    );
in
{
  inherit tree make-hierarchical-options;
}
