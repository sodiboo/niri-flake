{
  lib,
  kdl,
  fragments,
  niri-flake-internal,
  toplevel-options,
}:
let
  inherit (niri-flake-internal)
    fmt
    nullable
    required
    rename
    record'
    subopts
    link-opt
    make-ordered-options
    section'
    docs-only
    shorthand-for
    ;

  switch-bind = record' "niri switch bind" {
    action = required (rename "niri switch action" kdl.types.kdl-leaf) // {
      description = ''
        A switch action is represented as an attrset with a single key, being the name, and a value that is a list of its arguments.

        See also ${link-opt ((subopts toplevel-options.binds).action)} for more information on how this works, it has the exact same option type. Beware that switch binds are not the same as regular binds, and the actions they take are different. Currently, they can only accept spawn binds. Correct usage is like so:

        ${fmt.nix-code-block ''
          {
            ${toplevel-options.switch-events} = {
              tablet-mode-on.action.spawn = ["gsettings" "set" "org.gnome.desktop.a11y.applications" "screen-keyboard-enabled" "true"];
              tablet-mode-off.action.spawn = ["gsettings" "set" "org.gnome.desktop.a11y.applications" "screen-keyboard-enabled" "false"];
            };
          }
        ''}
      '';
    };
  };

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

  switch-bind' = name: {
    options.${name} = nullable (shorthand-for "switch-bind" switch-bind) // {
      visible = "shallow";
    };
    render = config: [
      (lib.mkIf (config.${name} != null) [
        (kdl.plain name [
          (lib.mapAttrsToList kdl.leaf config.${name}.action)
        ])
      ])
    ];
  };
in
{
  sections = [
    {
      options.switch-events =
        rendered-ordered-section
          [
            (switch-bind' "tablet-mode-on")
            (switch-bind' "tablet-mode-off")
            (switch-bind' "lid-open")
            (switch-bind' "lid-close")
            {
              options."<switch-bind>" = docs-only switch-bind // {
                override-loc = lib.const [ "<switch-bind>" ];
                description = ''
                  <!--
                  This description doesn't matter to the docs, but is necessary to make this header actually render so the above types can link to it.
                  -->
                '';
              };
              render = _: [ ];
            }
          ]
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
              config.rendered = kdl.plain "switch-events" [
                content
              ];
            }
          );

      render = config: config.switch-events.rendered;
    }
  ];
}
