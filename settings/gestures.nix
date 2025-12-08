{
  lib,
  kdl,
  niri-flake-internal,
  toplevel-options,
}:
let
  inherit (lib)
    types
    ;

  inherit (niri-flake-internal)
    float-or-int
    nullable
    optional
    section
    ;

  scroll-description.trigger = measure: ''
    The ${measure} of the edge of the screen where dragging a window will scroll the view.
  '';
  scroll-description.delay-ms = ''
    The delay in milliseconds before the view starts scrolling.
  '';
  scroll-description.max-speed-for = measure: ''
    When the cursor is at boundary of the trigger ${measure}, the view will not be scrolling. Moving the mouse further away from the boundary and closer to the egde will linearly increase the scrolling speed, until the mouse is pressed against the edge of the screen, at which point the view will scroll at this speed. The speed is measured in logical pixels per second.
  '';
in
{
  sections = [
    {
      options.gestures = {
        dnd-edge-view-scroll =
          section {
            trigger-width = nullable float-or-int // {
              description = scroll-description.trigger "width";
            };
            delay-ms = nullable types.int // {
              description = scroll-description.delay-ms;
            };
            max-speed = nullable float-or-int // {
              description = scroll-description.max-speed-for "width";
            };
          }
          // {
            description = ''
              When dragging a window to the left or right edge of the screen, the view will start scrolling in that direction.
            '';
          };
        dnd-edge-workspace-switch =
          section {
            trigger-height = nullable float-or-int // {
              description = scroll-description.trigger "height";
            };
            delay-ms = nullable types.int // {
              description = scroll-description.delay-ms;
            };
            max-speed = nullable float-or-int // {
              description = scroll-description.max-speed-for "height";
            };
          }
          // {
            description = ''
              In the overview, when dragging a window to the top or bottom edge of the screen, view will start scrolling in that direction.

              This does not happen when the overview is not open.
            '';
          };
        hot-corners.enable = optional types.bool true // {
          description = ''
            Put your mouse at the very top-left corner of a monitor to toggle the overview. Also works during drag-and-dropping something.
          '';
        };
      };
    }
  ];
}
