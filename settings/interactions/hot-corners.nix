{
  lib,
  kdl,
  fragments,
  niri-flake-internal,
  toplevel-options,
}:

let
  inherit (lib) types;

  inherit (niri-flake-internal)
    fmt
    make-ordered-options
    optional
    float-or-int
    nullable
    section'
    section
    record
    required
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
[
  {
    gesture = {
      options.hot-corners =
        rendered-ordered-section
          ([
            {
              options.enable = optional types.bool true // {
                description = ''
                  Put your mouse at the very top-left corner of a monitor to toggle the overview. Also works during drag-and-dropping something.
                '';
              };
              render = _: [ ];
            }
          ])
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
              config.rendered = kdl.plain "hot-corners" [
                (lib.mkIf (!config.enable) (kdl.flag "off"))
                (lib.mkIf (config.enable) [ content ])
              ];
            }
          );
      render = config: config.hot-corners.rendered;
    };
  }
]
