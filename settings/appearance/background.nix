{
  lib,
  kdl,
  hierarchies,
  niri-flake-internal,
  toplevel-options,
  ...
}:

let
  inherit (lib) types;

  inherit (niri-flake-internal)
    fmt
    nullable
    subopts
    ;

  inherit (hierarchies) overview-options layout-options;
in
[
  (overview-options.output-level (ctx: {
    options.backdrop-color = nullable types.str // {
      description = ''
        The backdrop is the layer of solid color at the very back of the scene that niri draws. Because there's nothing behind it to blend with, its alpha channel will be ignored.

        The backdrop is visible behind the workspaces in the overview, or between workspaces when switching.

        See also ${
          ctx.link-opt-contextual {
            global = (subopts toplevel-options.layout).background-color;
            output = (subopts (subopts toplevel-options.outputs).layout).background-color;
          }
        }, which is drawn for each workspace and goes in front of the backdrop.
      '';
    };
    render = config: [
      (lib.mkIf (config.backdrop-color != null) [
        (kdl.leaf "backdrop-color" config.backdrop-color)
      ])
    ];
  }))
  (layout-options.workspace-level (ctx: {
    options.background-color = ctx.nullable "background-color" {
      type = types.str;
      description = ''
        The background is a solid-colored layer drawn behind each workspace.

        It's visible through transparent windows, between ${fmt.link-opt-masked ctx.options.gaps "gaps"}, and inside any ${fmt.link-opt-masked ctx.options.struts "struts"}

        See also ${
          ctx.link-opt-contextual {
            global = (subopts toplevel-options.overview).backdrop-color;
            output = (subopts toplevel-options.outputs).backdrop-color;
            workspace = (subopts toplevel-options.outputs).backdrop-color;
          }
        }, which is drawn at the back of each monitor, behind the workspace background.
      '';
    };
    render = config: [
      (lib.mkIf (config.background-color != null) [
        (kdl.leaf "background-color" config.background-color)
      ])
    ];
  }))
  {
    output = {
      extra-modules = [
        (lib.mkRenamedOptionModule [ "background-color" ] [ "layout" "background-color" ])
      ];
      options = { };
      render = _: [ ];
    };
  }
]
