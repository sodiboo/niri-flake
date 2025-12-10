{
  lib,
  config,
  options,

  kdl,
  niri-flake-internal,
  ...
}:
let
  toplevel-options = options;
  inherit (lib)
    types
    ;
  inherit (lib.types) nullOr enum;
  inherit (niri-flake-internal)
    make-ordered-options
    ;
in

let
  files =
    map
      (
        f:
        import f {
          inherit
            lib
            kdl
            fragments
            niri-flake-internal
            toplevel-options
            ;
        }
      )
      [
        ./input.nix
        ./outputs.nix
        ./binds.nix
        ./switch-events.nix
        ./layout.nix
        ./overview.nix

        ./workspaces.nix

        ./misc.nix

        ./surface-rules.nix
        ./animations.nix
        ./gestures.nix

        ./debug.nix
      ];

  fragments = lib.mergeAttrsList (builtins.map (f: f.fragments or { }) files);

  sections = builtins.concatMap (f: f.sections or [ ]) files;

  render-utils = rec {
    normalize-nodes = nodes: lib.remove null (lib.flatten nodes);

    node =
      name: args: children:
      kdl.node name args (normalize-nodes children);
    plain = name: node name [ ];
    leaf = name: args: node name args [ ];
    flag = name: node name [ ] [ ];

    optional-node = cond: v: if cond then v else null;

    nullable =
      f: name: value:
      optional-node (value != null) (f name value);
    flag' = name: lib.flip optional-node (flag name);
    plain' =
      name: children:
      optional-node (builtins.any (v: v != null) (lib.flatten children)) (plain name children);

    map' =
      node: f: name: val:
      node name (f val);

    each = list: f: map f list;
    each' = attrs: each (builtins.attrValues attrs);

    toggle =
      disabled: cfg: contents:
      if cfg.enable then contents else flag disabled;

    toggle' = disabled: cfg: contents: [
      (flag' disabled (cfg.enable == false))
      contents
    ];
  };
in
{
  imports = (make-ordered-options (map (s: s.options) sections));
  options.rendered = lib.mkOption {
    type = kdl.types.kdl-document;
    readOnly = true;
  };
  config.rendered =
    let
      cfg = config;
      inherit (render-utils)
        normalize-nodes
        leaf
        plain'
        map'
        ;
    in
    normalize-nodes [
      (map' plain' (lib.mapAttrsToList leaf) "debug" cfg.debug)

    ]
    ++ map (s: (s.render or (_: [ ])) config) sections;
}
