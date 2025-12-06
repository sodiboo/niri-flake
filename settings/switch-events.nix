{
  lib,
  kdl,
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
    ordered-section
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

  switch-bind' = nullable (shorthand-for "switch-bind" switch-bind) // {
    visible = "shallow";
  };
in
ordered-section [
  {
    tablet-mode-on = switch-bind';
    tablet-mode-off = switch-bind';
    lid-open = switch-bind';
    lid-close = switch-bind';
  }
  {
    "<switch-bind>" = docs-only switch-bind // {
      override-loc = lib.const [ "<switch-bind>" ];
      description = ''
        <!--
        This description doesn't matter to the docs, but is necessary to make this header actually render so the above types can link to it.
        -->
      '';
    };
  }
]
