{
  lib,
  kdl,
  niri-flake-internal,
  toplevel-options,
  ...
}:

let
  inherit (lib) types;

  inherit (niri-flake-internal)
    fmt
    nullable
    link-opt
    link-opt-masked
    subopts
    ;

in
[
  (
    let
      make-backdrop =
        {
          extra-description,
        }:
        {
          options.backdrop-color = nullable types.str // {
            description = ''
              The backdrop is the layer of solid color at the very back of the scene that niri draws. Because there's nothing behind it to blend with, its alpha channel will be ignored.

              The backdrop is visible behind the workspaces in the overview, or between workspaces when switching.

              ${extra-description}
            '';
          };
          render = config: [
            (lib.mkIf (config.backdrop-color != null) [
              (kdl.leaf "backdrop-color" config.backdrop-color)
            ])
          ];
        };
    in
    {
      overview = make-backdrop {
        extra-description = ''
          You can override the backdrop color for an output with ${link-opt (subopts toplevel-options.outputs).backdrop-color}

          See also ${link-opt (subopts toplevel-options.layout).background-color}, which is drawn for each workspace and goes in front of the backdrop.
        '';
      };

      output = make-backdrop {
        extra-description = ''
          To set the backdrop color for all outputs, see ${link-opt (subopts toplevel-options.overview).backdrop-color}

          See also ${link-opt (subopts toplevel-options.layout).background-color}, which is drawn for each workspace and goes in front of the backdrop.
        '';
      };
    }
  )
  (
    let
      make-background =
        {
          extra-description,
        }:
        {
          options.background-color = nullable types.str // {
            description = ''
              The background is a solid-colored layer drawn behind each workspace.

              It's visible through transparent windows, between ${link-opt-masked (subopts toplevel-options.layout).gaps "gaps"}, and inside any ${link-opt-masked (subopts toplevel-options.layout).struts "struts"}

              ${extra-description}
            '';
          };
          render = config: [
            (lib.mkIf (config.background-color != null) [
              (kdl.leaf "background-color" config.background-color)
            ])
          ];
        };
    in
    {
      layout = make-background {
        extra-description = ''
          You can override the background color for an output with ${link-opt (subopts toplevel-options.outputs).background-color}

          See also ${link-opt (subopts toplevel-options.overview).backdrop-color}, which is drawn at the back of each monitor, behind the workspace background.
        '';
      };

      output = make-background {
        extra-description = ''
          To set the default background color for all outputs, see ${link-opt (subopts toplevel-options.overview).backdrop-color}

          See also ${link-opt (subopts toplevel-options.outputs).backdrop-color}, which is drawn at the back of each monitor, behind the workspace background.
        '';
      };
    }
  )
]
