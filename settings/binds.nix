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
    fmt
    nullable
    required
    rename
    optional
    ;

  make-rendered-binds-options = sections: [
    (
      { config, name, ... }:
      {
        options.rendered = {
          name = lib.mkOption {
            type = lib.types.str;
            readOnly = true;
            internal = true;
            visible = false;
          };
          properties = lib.mkOption {
            type = lib.types.attrsOf kdl.types.kdl-value;
            internal = true;
            visible = false;
          };
          children = lib.mkOption {
            type = kdl.types.kdl-document;
            readOnly = true;
            internal = true;
            visible = false;
          };
        };

        config.rendered.name = name;

        imports = (
          map (
            s:
            { config, ... }:
            {
              inherit (s) options;
              config.rendered = s.render config;
            }
          ) sections
        );
      }
    )
  ];

in
{
  sections = [
    {
      options.binds = lib.mkOption {
        default = { };

        type = lib.types.attrsOf (
          types.submoduleWith {
            description = "niri keybind";
            shorthandOnlyDefinesConfig = true;
            modules = make-rendered-binds-options [
              {
                options.allow-when-locked = optional types.bool false // {
                  description = ''
                    Whether this keybind should be allowed when the screen is locked.

                    This is only applicable for ${fmt.code "spawn"} keybinds.
                  '';
                };
                render = config: {
                  properties.allow-when-locked = lib.mkIf (
                    config.allow-when-locked != false
                  ) config.allow-when-locked;
                };
              }
              {

                options.allow-inhibiting = optional types.bool true // {
                  description = ''
                    When a surface is inhibiting keyboard shortcuts, this option dictates wether ${fmt.em "this"} keybind will be inhibited as well.

                    By default it is true for all keybinds, meaning an application can block this keybind from being triggered, and the application will receive the key event instead.

                    When false, this keybind will always be triggered, even if an application is inhibiting keybinds. There is no way for a client to observe this keypress.

                    Has no effect when ${fmt.code "action"} is ${fmt.code "toggle-keyboard-shortcuts-inhibit"}. In that case, this value is implicitly false, no matter what you set it to. (note that the value reported in the nix config may be inaccurate in that case; although hopefully you're not relying on the values of specific keybinds for the rest of your config?)
                  '';
                };

                render = config: {
                  properties.allow-inhibiting = lib.mkIf (config.allow-inhibiting != true) config.allow-inhibiting;
                };
              }
              {
                options.cooldown-ms = nullable types.int // {
                  description = ''
                    The minimum cooldown before a keybind can be triggered again, in milliseconds.

                    This is mostly useful for binds on the mouse wheel, where you might not want to activate an action several times in quick succession. You can use it for any bind, though.
                  '';
                };
                render = config: {
                  properties.cooldown-ms = lib.mkIf (config.cooldown-ms != null) config.cooldown-ms;
                };
              }
              {
                options.repeat = optional types.bool true // {
                  description = ''
                    Whether this keybind should trigger repeatedly when held down.
                  '';
                };
                render = config: {
                  properties.repeat = lib.mkIf (config.repeat != true) config.repeat;
                };
              }
              {
                options.hotkey-overlay =
                  optional
                    (types.attrTag {
                      hidden = lib.mkOption {
                        type = types.bool;
                        description = ''
                          When ${fmt.code "true"}, the hotkey overlay will not contain this keybind at all. When ${fmt.code "false"}, it will show the default title of the action.
                        '';
                      };
                      title = lib.mkOption {
                        type = types.str;
                        description = ''
                          The title of this keybind in the hotkey overlay. ${
                            fmt.masked-link {
                              href = "https://docs.gtk.org/Pango/pango_markup.html";
                              content = "Pango markup";
                            }
                          } is supported.
                        '';
                      };
                    })
                    {
                      hidden = false;
                    }
                  // {
                    description = ''
                      How this keybind should be displayed in the hotkey overlay.

                      ${fmt.list [
                        ''
                          By default, ${fmt.code "{hidden = false;}"} maps to omitting this from the KDL config; the default title of the action will be used.
                        ''
                        ''
                          ${fmt.code "{hidden = true;}"} will emit ${fmt.code "hotkey-overlay-title=null"} in the KDL config, and the hotkey overlay will not contain this keybind at all.
                        ''
                        ''
                          ${fmt.code ''{title = "foo";}''} will emit ${fmt.code ''hotkey-overlay-title="foo"''} in the KDL config, and the hotkey overlay will show "foo" as the title of this keybind.
                        ''
                      ]}
                    '';
                  };
                render = config: {
                  properties.hotkey-overlay-title =
                    config.hotkey-overlay.title or (lib.mkIf (config.hotkey-overlay.hidden) null);
                };
              }
              {
                options.action = required (rename "niri action" kdl.types.kdl-leaf) // {
                  description = ''
                    An action is represented as an attrset with a single key, being the name, and a value that is a list of its arguments. For example, to represent a spawn action, you could do this:

                    ${fmt.nix-code-block ''
                      {
                        ${toplevel-options.binds} = {
                          "XF86AudioRaiseVolume".action.spawn = ["wpctl" "set-volume" "@DEFAULT_AUDIO_SINK@" "0.1+"];
                          "XF86AudioLowerVolume".action.spawn = ["wpctl" "set-volume" "@DEFAULT_AUDIO_SINK@" "0.1-"];
                        };
                      }
                    ''}

                    If there is only a single argument, you can pass it directly. It will be implicitly converted to a list in that case.

                    ${fmt.nix-code-block ''
                      {
                        ${toplevel-options.binds} = {
                          "Mod+D".action.spawn = "fuzzel";
                          "Mod+1".action.focus-workspace = 1;
                        };
                      }
                    ''}

                    For actions taking properties (named arguments), you can pass an attrset.

                    ${fmt.nix-code-block ''
                      {
                        ${toplevel-options.binds} = {
                          "Mod+Shift+E".action.quit.skip-confirmation = true;
                          "Mod+Print".action.screenshot-screen = { show-pointer = false; };
                        };
                      }
                    ''}

                    If an action takes properties and positional arguments, you can write it like this:

                    ${fmt.nix-code-block ''
                      {
                        ${toplevel-options.binds} = {
                          "Mod+Ctrl+1".action.move-window-to-workspace = [ { focus = false; } "chat-apps" ];
                        };
                      }
                    ''}
                  ''

                  #   + ''
                  #   There is also a set of functions available under ${fmt.code "config.lib.niri.actions"}.

                  #   Usage is like so:

                  #   ${fmt.nix-code-block ''
                  #     {
                  #       ${toplevel-options.binds} = with config.lib.niri.actions; {
                  #         "XF86AudioRaiseVolume".action = spawn "wpctl" "set-volume" "@DEFAULT_AUDIO_SINK@" "0.1+";
                  #         "XF86AudioLowerVolume".action = spawn "wpctl" "set-volume" "@DEFAULT_AUDIO_SINK@" "0.1-";

                  #         "Mod+D".action = spawn "fuzzel";
                  #         "Mod+1".action = focus-workspace 1;

                  #         "Mod+Shift+E".action = quit;
                  #         "Mod+Ctrl+Shift+E".action = quit { skip-confirmation=true; };

                  #         "Mod+Plus".action = set-column-width "+10%";
                  #       }
                  #     }
                  #   ''}

                  #   Keep in mind that each one of these attributes (i.e. the nix bindings) are actually identical functions with different node names, and they can take arbitrarily many arguments. The documentation here is based on the ${fmt.em "real"} acceptable arguments for these actions, but the nix bindings do not enforce this. If you pass the wrong arguments, niri will reject the config file, but evaluation will proceed without problems.

                  #   For actions that don't take any arguments, just use the corresponding attribute from ${fmt.code "config.lib.niri.actions"}. They are listed as ${fmt.code "action-name"}. For actions that ${fmt.em "do"} take arguments, they are notated like so: ${fmt.code "λ action-name :: <args>"}, to clarify that they "should" be used as functions. Hopefully, ${fmt.code "<args>"} will be clear enough in most cases, but it's worth noting some nontrivial kinds of arguments:

                  #   ${fmt.list [
                  #     ''
                  #       ${fmt.code "size-change"}: This is a special argument type used for some actions by niri. It's a string. \
                  #       It can take either a fixed size as an integer number of logical pixels (${fmt.code ''"480"''}, ${fmt.code ''"1200"''}) or a proportion of your screen as a percentage (${fmt.code ''"30%"''}, ${fmt.code ''"70%"''}) \
                  #       Additionally, it can either be an absolute change (setting the new size of the window), or a relative change (adding or subtracting from its size). \
                  #       Relative size changes are written with a ${fmt.code "+"}/${fmt.code "-"} prefix, and absolute size changes have no prefix.
                  #     ''
                  #     ''
                  #       ${fmt.code "{ field :: type }"}: This means that the action takes a named argument (in kdl, we call it a property). \
                  #       To pass such an argument, you should pass an attrset with the key and value. You can pass many properties in one attrset, or you can pass several attrsets with different properties. \
                  #       Required fields are marked with ${fmt.code "*"} before their name, and if no fields are required, you can use the action without any arguments too (see ${fmt.code "quit"} in the example above). \
                  #       If a field is marked with ${fmt.code "?"}, then omitting it is meaningful. (without ${fmt.code "?"}, it will have a default value)
                  #     ''
                  #     ''
                  #       ${fmt.code "[type]"}: This means that the action takes several arguments as a list. Although you can pass a list directly, it's more common to pass them as separate arguments. \
                  #       ${fmt.code ''spawn ["foo" "bar" "baz"]''} is equivalent to ${fmt.code ''spawn "foo" "bar" "baz"''}.
                  #     ''
                  #   ]}

                  #   ${fmt.admonition.tip ''
                  #     You can use partial application to create a spawn command with full support for shell syntax:
                  #     ${fmt.nix-code-block ''
                  #       {
                  #         ${toplevel-options.binds} = with config.lib.niri.actions; let
                  #           sh = spawn "sh" "-c";
                  #         in {
                  #           "Print".action = sh '''grim -g "$(slurp)" - | wl-copy''';
                  #         };
                  #       }
                  #     ''}
                  #   ''}

                  #   ${
                  #     let
                  #       show-bind =
                  #         {
                  #           name,
                  #           params,
                  #           ...
                  #         }:
                  #         let
                  #           is-stable = builtins.any (a: a.name == name) binds-stable;
                  #           is-unstable = builtins.any (a: a.name == name) binds-unstable;
                  #           exclusive =
                  #             if is-stable && is-unstable then
                  #               ""
                  #             else if is-stable then
                  #               " (only on niri-stable)"
                  #             else
                  #               " (only on niri-unstable)";
                  #           type-names = {
                  #             LayoutSwitchTarget = ''"next" | "prev"'';
                  #             WorkspaceReference = "u8 | string";
                  #             SizeChange = "size-change";
                  #             bool = "bool";
                  #             u8 = "u8";
                  #             u16 = "u16";
                  #             String = "string";
                  #           };

                  #           type-or =
                  #             rust-name: fallback: type-names.${rust-name} or (lib.warn "unhandled type `${rust-name}`" fallback);

                  #           base = content: "${fmt.code content}${exclusive}";
                  #           lambda = args: base "λ ${name} :: ${args}";
                  #         in
                  #         {
                  #           empty = base "${name}";
                  #           arg = lambda (type-or params.type (if params.as-str then "string" else params.type));
                  #           list = lambda "[${type-or params.type params.type}]";
                  #           prop = lambda "{ ${
                  #             lib.optionalString (!params.use-default) "*"
                  #           }${params.field}${lib.optionalString params.none-important "?"} :: ${
                  #             type-names.${params.type} or (lib.warn "unhandled type `${params.type}`" params.type)
                  #           } }";
                  #           unknown = ''
                  #             ${lambda "unknown"}

                  #               The code that generates this documentation does not know how to parse the definition:
                  #               ```rs
                  #               ${params.raw-name}(${params.raw})
                  #               ```
                  #           '';
                  #         }
                  #         .${params.kind}
                  #           or (abort "action `${name}` with unhandled kind `${params.kind}` for settings docs");
                  #     in
                  #     fmt.list (
                  #       (map show-bind (
                  #         builtins.filter (
                  #           stable: builtins.all (unstable: stable.name != unstable.name) binds-unstable
                  #         ) binds-stable
                  #       ))
                  #       ++ (map show-bind binds-unstable)
                  #     )
                  #   }
                  # ''
                  ;
                };
                render = config: {
                  children = lib.mapAttrsToList kdl.leaf config.action;
                };
              }
            ];
          }
        );
      };

      render = config: [
        (lib.mkIf (config.binds != { }) [
          (kdl.plain "binds" [
            (map (cfg: cfg.rendered) (builtins.attrValues config.binds))
          ])
        ])
      ];
    }
  ];
}
