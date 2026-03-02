{
  lib,
  kdl,
  niri-flake-internal,
  toplevel-options,
  appearance,
  ...
}:
let
  inherit (lib)
    types
    ;
  inherit (niri-flake-internal)
    fmt
    nullable
    make-ordered-options
    ;
in
[
  {
    options.workspaces = lib.mkOption {
      description = ''
        Declare named workspaces.

        Named workspaces are similar to regular, dynamic workspaces, except they can be
        referred to by name, and they are persistent, they do not close when there are
        no more windows left on them.

        Usage is like so:

        ${fmt.nix-code-block ''
          {
            ${toplevel-options.workspaces}."name" = {};
            ${toplevel-options.workspaces}."01-another-one" = {
              open-on-output = "DP-1";
              name = "another-one";
            };
          }
        ''}

        Unless a ${fmt.code "name"} is declared, the workspace will use the attribute key as the name.

        Workspaces will be created in a specific order: sorted by key. If you do not care
        about the order of named workspaces, you can skip using the ${fmt.code "name"} attribute, and
        use the key instead. If you do care about it, you can use the key to order them,
        and a ${fmt.code "name"} attribute to have a friendlier name.
      '';

      default = { };
      type = lib.types.attrsOf (
        lib.types.submodule (
          make-ordered-options
            {
              finalize =
                rendered:
                { name, config, ... }:
                {
                  options.rendered = lib.mkOption {
                    type = kdl.types.kdl-node;
                    readOnly = true;
                    internal = true;
                    visible = false;
                  };

                  config.rendered = kdl.node "workspace" config.name [
                    [ rendered ]
                  ];

                  config.name = lib.mkOptionDefault name;
                };
            }
            [
              {
                options.name = lib.mkOption {
                  type = types.str;
                  defaultText = "the key of the workspace";
                  description = ''
                    The name of the workspace. You set this manually if you want the keys to be ordered in a specific way.
                  '';
                };
                render = _: [ ];
              }
              {
                options.open-on-output = nullable types.str // {
                  description = ''
                    The name of the output the workspace should be assigned to.
                  '';
                };
                render = config: [
                  (lib.mkIf (config.open-on-output != null) [
                    (kdl.leaf "open-on-output" config.open-on-output)
                  ])
                ];
              }
              appearance.workspace
            ]
        )
      );
    };

    render = cfg: map (cfg: cfg.rendered) (builtins.attrValues cfg.workspaces);
  }
]
