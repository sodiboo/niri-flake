{
  lib,
  kdl,
  niri-flake-internal,
  toplevel-options,
  interactions,
  ...
}:
let
  inherit (lib)
    types
    ;

  inherit (niri-flake-internal)
    float-or-int
    nullable
    make-rendered-section
    ;

  make-dnd-gesture =
    name:
    {
      description,
      measure,
    }:
    {
      options.${name} =
        make-rendered-section name
          {
            partial = true;
            inherit description;
          }
          [
            {
              options."trigger-${measure}" = nullable float-or-int // {
                description = ''
                  The ${measure} of the edge of the screen where dragging a window will scroll the view.
                '';
              };
              render = config: [
                (lib.mkIf (config."trigger-${measure}" != null) [
                  (kdl.leaf "trigger-${measure}" config."trigger-${measure}")
                ])
              ];
            }
            {
              options.delay-ms = nullable types.int // {
                description = ''
                  The delay in milliseconds before the view starts scrolling.
                '';
              };
              render = config: [
                (lib.mkIf (config.delay-ms != null) [
                  (kdl.leaf "delay-ms" config.delay-ms)
                ])
              ];
            }
            {
              options.max-speed = nullable float-or-int // {
                description = ''
                  When the cursor is at boundary of the trigger ${measure}, the view will not be scrolling. Moving the mouse further away from the boundary and closer to the egde will linearly increase the scrolling speed, until the mouse is pressed against the edge of the screen, at which point the view will scroll at this speed. The speed is measured in logical pixels per second.
                '';
              };

              render = config: [
                (lib.mkIf (config.max-speed != null) [
                  (kdl.leaf "max-speed" config.max-speed)
                ])
              ];
            }
          ];
      render = config: config.${name}.rendered;
    };
in
[
  {
    options.gestures = make-rendered-section "gestures" { partial = true; } [
      (make-dnd-gesture "dnd-edge-view-scroll" {
        description = ''
          When dragging a window to the left or right edge of the screen, the view will start scrolling in that direction.
        '';
        measure = "width";
      })
      (make-dnd-gesture "dnd-edge-workspace-switch" {
        description = ''
          In the overview, when dragging a window to the top or bottom edge of the screen, view will start scrolling in that direction.

          This does not happen when the overview is not open.
        '';
        measure = "height";
      })
      interactions.gestures
    ];
    render = config: config.gestures.rendered;
  }
]
