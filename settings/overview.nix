{
  lib,
  kdl,
  fragments,
  niri-flake-internal,
  toplevel-options,
}:
let
  appearance = import ./appearance {
    inherit
      lib
      kdl
      fragments
      niri-flake-internal
      toplevel-options
      ;
  };

  inherit (lib)
    types
    ;
  inherit (niri-flake-internal)
    nullable
    float-or-int
    make-ordered-options
    section'
    ;

  make-rendered-ordered-options = sections: final: [
    (
      { config, ... }:
      {
        imports = make-ordered-options (map (s: s.options) sections) ++ [
          (final (map (s: s.render config) sections))
        ];
      }
    )
  ];

  rendered-ordered-section = sections: final: section' (make-rendered-ordered-options sections final);
in
{
  sections = [
    {
      options.overview =
        rendered-ordered-section
          (
            appearance.overview
            ++ [
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
              {
                options.backdrop-color = nullable types.str // {
                  description = ''
                    Set the backdrop color behind workspaces in the overview. The backdrop is also visible between workspaces when switching.

                    The alpha channel for this color will be ignored.
                  '';
                };
                render = config: [
                  (lib.mkIf (config.backdrop-color != null) [
                    (kdl.leaf "backdrop-color" config.backdrop-color)
                  ])
                ];
              }
            ]
          )
          (
            content:
            { config, ... }:
            {
              options.rendered = lib.mkOption {
                type = kdl.types.kdl-node;
                readOnly = true;
                internal = true;
                visible = false;
                apply = node: lib.mkIf (node.children != [ ]) node;
              };
              config.rendered = kdl.plain "overview" [
                content
              ];
            }
          );

      render = config: config.overview.rendered;
    }
  ];
}
