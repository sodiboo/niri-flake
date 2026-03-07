{
  lib,
  niri-flake-utils,
  niri-flake-internal,
  toplevel-options,
  ...
}@args:
let
  inherit (niri-flake-internal) subopts;

  inherit (niri-flake-utils) hierarchy;

  layout-options =
    f:
    let
      at-position =
        position:
        f (
          hierarchy.make-hierarchical-options {
            scope = [
              "window"
              "layer"
            ];
            inherit position;
            hierarchy = [
              (hierarchy.tree.node "global" {
                options = subopts toplevel-options.layout;
                children = [
                  (hierarchy.tree.node "output" {
                    options = subopts (subopts toplevel-options.outputs).layout;
                    children = [
                      (hierarchy.tree.node "workspace" {
                        options = subopts (subopts toplevel-options.workspaces).layout;
                        children = [
                          (hierarchy.tree.node "window" {
                            options = subopts toplevel-options.window-rules;
                          })
                          (hierarchy.tree.node "layer" {
                            options = subopts toplevel-options.layer-rules;
                          })
                        ];
                      })
                    ];
                  })
                ];
              })
            ];
          }
        );
    in
    {
      global-layout = at-position "global";
      output-layout = at-position "output";
      workspace-layout = at-position "workspace";
      window-rule = at-position "window";
      layer-rule = at-position "layer";
    };

  overview-options =
    f:
    let
      at-position =
        position:
        f (
          hierarchy.make-hierarchical-options {
            hierarchy = [
              (hierarchy.tree.node "global" {
                options = subopts toplevel-options.overview;
                children = [
                  (hierarchy.tree.node "output" {
                    options = subopts toplevel-options.outputs;
                  })
                ];
              })
            ];
            scope = [ "output" ];
            inherit position;
          }
        );
    in
    {
      overview = at-position "global";
      output = at-position "output";
    };

  layout-definition =
    f:
    let
      at-position =
        position:
        f (
          hierarchy.make-hierarchical-options {
            hierarchy = [
              (hierarchy.tree.node "global" {
                options = toplevel-options;
                children = [
                  (hierarchy.tree.node "output" {
                    options = subopts toplevel-options.outputs;
                    children = [
                      (hierarchy.tree.node "workspace" {
                        options = subopts toplevel-options.workspaces;
                      })
                    ];
                  })
                ];
              })
            ];
            scope = [ "workspace" ];
            inherit position;
          }
        );
    in
    {
      toplevel = at-position "global";
      output = at-position "output";
      workspace = at-position "workspace";
    };

  args' = args // {
    hierarchies = {
      layout-options.global-level = f: layout-options (ctx: ctx.global-level f);
      layout-options.output-level = f: layout-options (ctx: ctx.output-level f);
      layout-options.workspace-level = f: layout-options (ctx: ctx.workspace-level f);
      layout-options.window-level = f: layout-options (ctx: ctx.window-level f);
      layout-options.layer-level = f: layout-options (ctx: ctx.layer-level f);
      layout-options.surface-agnostic = layout-options;

      overview-options.global-level = f: overview-options (ctx: ctx.global-level f);
      overview-options.output-level = f: overview-options (ctx: ctx.output-level f);

      layout-definition = layout-definition;
    };
  };

  elements = lib.zipAttrs (
    builtins.concatMap (f: map (builtins.mapAttrs (_: lib.setDefaultModuleLocation f)) (import f args'))
      [
        ./background.nix
        ./layout.nix
        ./decorations.nix
        ./shadows.nix
      ]
  );
in
{
  overview = elements.overview or [ ];

  toplevel = elements.toplevel or [ ];
  global-layout = elements.global-layout or [ ];

  output = elements.output or [ ];
  output-layout = elements.output-layout or [ ];

  workspace = elements.workspace or [ ];
  workspace-layout = elements.workspace-layout or [ ];

  window-rules = elements.window-rule or [ ];
  layer-rules = elements.layer-rule or [ ];

}
