{
  lib,
  kdl,
  niri-flake-internal,
  toplevel-options,
  appearance,
  ...
}:
let
  inherit (niri-flake-internal)
    nullable
    float-or-int
    make-rendered-section
    ;
in
[
  {
    options.overview = make-rendered-section "overview" { partial = true; } [
      appearance.overview
      {
        options.zoom = nullable float-or-int // {
          description = ''
            Control how much the workspaces zoom out in the overview. zoom ranges from 0 to 0.75 where lower values make everything smaller.
          '';
        };
        render = config: [
          (lib.mkIf (config.zoom != null) [
            (kdl.leaf "zoom" config.zoom)
          ])
        ];
      }
    ];

    render = config: config.overview.rendered;
  }
]
