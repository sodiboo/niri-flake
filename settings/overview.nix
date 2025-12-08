{
  lib,
  kdl,
  fragments,
  niri-flake-internal,
  toplevel-options,
}:
let
  inherit (lib)
    types
    ;
  inherit (niri-flake-internal)
    nullable
    float-or-int
    optional
    record
    ;

  inherit (fragments) shadow-descriptions;
in
{
  sections = [
    {
      options.overview = {
        zoom = nullable float-or-int // {
          description = ''
            Control how much the workspaces zoom out in the overview. zoom ranges from 0 to 0.75 where lower values make everything smaller.
          '';
        };
        backdrop-color = nullable types.str // {
          description = ''
            Set the backdrop color behind workspaces in the overview. The backdrop is also visible between workspaces when switching.

            The alpha channel for this color will be ignored.
          '';
        };

        workspace-shadow = {
          enable = optional types.bool true;
          offset =
            nullable (record {
              x = optional float-or-int 0.0;
              y = optional float-or-int 5.0;
            })
            // {
              description = shadow-descriptions.offset;
            };

          softness = nullable float-or-int // {
            description = shadow-descriptions.softness;
          };

          spread = nullable float-or-int // {
            description = shadow-descriptions.spread;
          };

          color = nullable types.str;
        };
      };
    }
  ];
}
