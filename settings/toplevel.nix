{
  lib,
  options,

  kdl,
  niri-flake-internal,
  ...
}:
let
  toplevel-options = options;
  inherit (lib)
    types
    mkOptionType
    showOption
    mkOption
    ;
  inherit (lib.types) nullOr enum;
  inherit (niri-flake-internal)
    fmt
    link-opt
    subopts
    section'
    make-ordered-options
    make-decoration-options
    nullable
    float-or-int
    section
    record
    ordered-record'
    required
    shadow-descriptions
    rule-descriptions
    border-rule
    shadow-rule
    geometry-corner-radius-rule
    regex
    list
    attrs
    default-width
    default-height
    shorthand-for
    ordered-section
    docs-only
    attrs-record
    optional
    rename-warning
    obsolete-warning
    ;
in
{
  # config._module.niri-flake-ordered-record.ordering = lib.mkForce [
  #   "input"
  #   "outputs"
  #   "binds"
  #   "switch-events"
  #   "layout"

  #   "workspaces"

  #   "spawn-at-startup"
  #   "prefer-no-csd"
  #   "screenshot-path"
  #   "environment"
  #   "overview"
  #   "cursor"
  #   "xwayland-satellite"
  #   "clipboard"
  #   "hotkey-overlay"

  #   "window-rules"
  #   "layer-rules"
  #   "animations"
  #   "gestures"

  #   "debug"
  # ];
  imports = make-ordered-options [
    {
      switch-events = import ./switch-events.nix {
        inherit
          lib
          kdl
          niri-flake-internal
          toplevel-options
          ;
      };

      binds = import ./binds.nix {
        inherit
          lib
          kdl
          niri-flake-internal
          toplevel-options
          ;
      };
    }

    {
      screenshot-path =
        optional (nullOr types.str) "~/Pictures/Screenshots/Screenshot from %Y-%m-%d %H-%M-%S.png"
        // {
          description = ''
            The path to save screenshots to.

            If this is null, then no screenshots will be saved.

            If the path starts with a ${fmt.code "~"}, then it will be expanded to the user's home directory.

            The path is then passed to ${
              fmt.masked-link {
                href = "https://man7.org/linux/man-pages/man3/strftime.3.html";
                content = fmt.code "strftime(3)";
              }
            } with the current time, and the result is used as the final path.
          '';
        };
    }

    {
      hotkey-overlay = {
        skip-at-startup = optional types.bool false // {
          description = ''
            Whether to skip the hotkey overlay shown when niri starts.
          '';
        };

        hide-not-bound = optional types.bool false // {
          description = ''
            By default, niri has a set of important keybinds that are always shown in the hotkey overlay, even if they are not bound to any key.
            In particular, this helps new users discover important keybinds, especially if their config has no keybinds at all.

            You can disable this behaviour by setting this option to ${fmt.code "true"}. Then, niri will only show keybinds that are actually bound to a key.
          '';
        };
      };
    }
    {
      config-notification = {
        disable-failed = optional types.bool false // {
          description = ''
            Disable the notification that the config file failed to load.
          '';
        };
      };
    }

    {
      clipboard.disable-primary = optional types.bool false // {
        description = ''
          The "primary selection" is a special clipboard that contains the text that was last selected with the mouse, and can usually be pasted with the middle mouse button.

          This is a feature that is not inherently part of the core Wayland protocol, but ${
            fmt.masked-link {
              href = "https://wayland.app/protocols/primary-selection-unstable-v1#compositor-support";
              content = "a widely supported protocol extension";
            }
          } enables support for it anyway.

          This functionality was inherited from X11, is not necessarily intuitive to many users; especially those coming from other operating systems that do not have this feature (such as Windows, where the middle mouse button is used for scrolling).

          If you don't want to have a primary selection, you can disable it with this option. Doing so will prevent niri from adveritising support for the primary selection protocol.

          Note that this option has nothing to do with the "clipboard" that is commonly invoked with ${fmt.kbd "Ctrl+C"} and ${fmt.kbd "Ctrl+V"}.
        '';
      };
    }

    {
      prefer-no-csd = optional types.bool false // {
        description = ''
          Whether to prefer server-side decorations (SSD) over client-side decorations (CSD).
        '';
      };
    }

    {
      spawn-at-startup =
        list (
          types.attrTag {
            argv = lib.mkOption {
              type = types.listOf types.str;
              description = ''
                Almost raw process arguments to spawn, without shell syntax.

                A leading tilde in the zeroth argument will be expanded to the user's home directory. No other preprocessing is applied.

                Usage is like so:

                ${fmt.nix-code-block ''
                  {
                    ${options.spawn-at-startup} = [
                      { argv = ["waybar"]; }
                      { argv = ["swaybg" "--image" "/path/to/wallpaper.jpg"]; }
                      { argv = ["~/.config/niri/scripts/startup.sh"]; }
                    ];
                  }
                ''}
              '';
            };
            sh = lib.mkOption {
              type = types.str;
              description = ''
                A shell command to spawn. Run wild with POSIX syntax.

                ${fmt.nix-code-block ''
                  {
                    ${options.spawn-at-startup} = [
                      { sh = "echo $NIRI_SOCKET > ~/.niri-socket"; }
                    ];
                  }
                ''}

                Note that ${fmt.code ''{ sh = "foo"; }''} is exactly equivalent to ${fmt.code ''{ argv = [ "sh" "-c" "foo" ]; }''}.
              '';
            };

            # alias of argv
            command = lib.mkOption {
              type = types.listOf types.str;
              visible = false;
            };
          }
        )
        // {
          description = ''
            A list of commands to run when niri starts.

            Each command can be represented as its raw arguments, or as a shell invocation.

            When niri is built with the ${fmt.code "systemd"} feature (on by default), commands spawned this way (or with the ${fmt.code "spawn"} and ${fmt.code "spawn-sh"} actions) will be put in a transient systemd unit, which separates the process from niri and prevents e.g. OOM situations from killing the entire session.
          '';
        };
    }

    {
      workspaces =
        attrs-record (key: {
          name = optional types.str key // {
            defaultText = "the key of the workspace";
            description = ''
              The name of the workspace. You set this manually if you want the keys to be ordered in a specific way.
            '';
          };
          open-on-output = nullable types.str // {
            description = ''
              The name of the output the workspace should be assigned to.
            '';
          };
        })
        // {
          description = ''
            Declare named workspaces.

            Named workspaces are similar to regular, dynamic workspaces, except they can be
            referred to by name, and they are persistent, they do not close when there are
            no more windows left on them.

            Usage is like so:

            ${fmt.nix-code-block ''
              {
                ${options.workspaces}."name" = {};
                ${options.workspaces}."01-another-one" = {
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
        };
    }

    {
      overview = {
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

    {
      input = import ./input.nix {
        inherit
          lib
          kdl
          niri-flake-internal
          toplevel-options
          ;
      };
    }

    {
      outputs = attrs-record (key: {
        name = optional types.str key // {
          defaultText = "the key of the output";
          description = ''
            The name of the output. You set this manually if you want the outputs to be ordered in a specific way.
          '';
        };
        enable = optional types.bool true;
        backdrop-color = nullable types.str // {
          description = ''
            The backdrop color that niri draws for this output. This is visible between workspaces or in the overview.
          '';
        };
        background-color = nullable types.str // {
          description = ''
            The background color of this output. This is equivalent to launching ${fmt.code "swaybg -c <color>"} on that output, but is handled by the compositor itself for solid colors.
          '';
        };
        scale = nullable float-or-int // {
          description = ''
            The scale of this output, which represents how many physical pixels fit in one logical pixel.

            If this is null, niri will automatically pick a scale for you.
          '';
        };
        transform = {
          flipped = optional types.bool false // {
            description = ''
              Whether to flip this output vertically.
            '';
          };
          rotation =
            optional (enum [
              0
              90
              180
              270
            ]) 0
            // {
              description = ''
                Counter-clockwise rotation of this output in degrees.
              '';
            };
        };
        position =
          nullable (record {
            x = required types.int;
            y = required types.int;
          })
          // {
            description = ''
              Position of the output in the global coordinate space.

              This affects directional monitor actions like "focus-monitor-left", and cursor movement.

              The cursor can only move between directly adjacent outputs.

              Output scale has to be taken into account for positioning, because outputs are sized in logical pixels.

              For example, a 3840x2160 output with scale 2.0 will have a logical size of 1920x1080, so to put another output directly adjacent to it on the right, set its x to 1920.

              If the position is unset or multiple outputs overlap, niri will instead place the output automatically.
            '';
          };
        mode =
          nullable (record {
            width = required types.int;
            height = required types.int;
            refresh = nullable types.float // {
              description = ''
                The refresh rate of this output. When this is null, but the resolution is set, niri will automatically pick the highest available refresh rate.
              '';
            };
          })
          // {
            description = ''
              The resolution and refresh rate of this display.

              By default, when this is null, niri will automatically pick a mode for you.

              If this is set to an invalid mode (i.e unsupported by this output), niri will act as if it is unset and pick one for you.
            '';
          };

        variable-refresh-rate =
          optional (enum [
            false
            "on-demand"
            true
          ]) false
          // {
            description = ''
              Whether to enable variable refresh rate (VRR) on this output.

              VRR is also known as Adaptive Sync, FreeSync, and G-Sync.

              Setting this to ${fmt.code ''"on-demand"''} will enable VRR only when a window with ${link-opt (subopts options.window-rules).variable-refresh-rate} is present on this output.
            '';
          };

        focus-at-startup = optional types.bool false // {
          description = ''
            Focus this output by default when niri starts.

            If multiple outputs with ${fmt.code "focus-at-startup"} are connected, then the one with the key that sorts first will be focused. You can change the key to affect the sorting order, and set ${link-opt (subopts options.outputs).name} to be the actual name of the output.

            When none of the connected outputs are explicitly focus-at-startup, niri will focus the first one sorted by name (same output sorting as used elsewhere in niri).
          '';
        };
      });
    }

    {
      cursor = section' {
        imports = [
          (lib.mkRenamedOptionModule [ "hide-on-key-press" ] [ "hide-when-typing" ])
        ];
        options = {
          theme = optional types.str "default" // {
            description = ''
              The name of the xcursor theme to use.

              This will also set the XCURSOR_THEME environment variable for all spawned processes.
            '';
          };
          size = optional types.int 24 // {
            description = ''
              The size of the cursor in logical pixels.

              This will also set the XCURSOR_SIZE environment variable for all spawned processes.
            '';
          };
          hide-when-typing = optional types.bool false // {
            description = ''
              Whether to hide the cursor when typing.
            '';
          };
          hide-after-inactive-ms = nullable types.int // {
            description = ''
              If set, the cursor will automatically hide once this number of milliseconds passes since the last cursor movement.
            '';
          };
        };
      };
    }

    {
      layout = import ./layout.nix {
        inherit
          lib
          kdl
          niri-flake-internal
          toplevel-options
          ;
      };
    }

    {
      animations =
        let
          animation-kind = types.attrTag {
            spring = section {
              damping-ratio = required types.float;
              stiffness = required types.int;
              epsilon = required types.float;
            };
            easing = section {
              duration-ms = required types.int;
              curve =
                required (enum [
                  "linear"
                  "ease-out-quad"
                  "ease-out-cubic"
                  "ease-out-expo"
                  "cubic-bezier"
                ])
                // {
                  description = ''
                    The curve to use for the easing function.
                  '';
                };

              # eh? not loving this. but anything better is kinda nontrivial.
              # will refactor, currently just a stopgap so that it is usable.
              curve-args = list kdl.types.kdl-value // {
                description = ''
                  Arguments to the easing curve. ${fmt.code "cubic-bezier"} requires 4 arguments, all others don't allow arguments.
                '';
              };
            };
          };

          anims = {
            workspace-switch.has-shader = false;
            horizontal-view-movement.has-shader = false;
            config-notification-open-close.has-shader = false;
            exit-confirmation-open-close.has-shader = false;
            window-movement.has-shader = false;
            window-open.has-shader = true;
            window-close.has-shader = true;
            window-resize.has-shader = true;
            screenshot-ui-open.has-shader = false;
            overview-open-close.has-shader = false;
          };
        in
        ordered-section [
          {
            enable = optional types.bool true;
            slowdown = nullable float-or-int;
          }
          {
            all-anims = mkOption {
              type = types.raw;
              internal = true;
              visible = false;

              default = builtins.attrNames anims;
            };
          }
          (builtins.mapAttrs (
            name:
            (
              { has-shader }:
              let
                inner = record (
                  {
                    enable = optional types.bool true;
                    kind = nullable (shorthand-for "animation-kind" animation-kind) // {
                      visible = "shallow";
                    };
                  }
                  // lib.optionalAttrs has-shader {
                    custom-shader = nullable types.str // {
                      description = ''
                        Source code for a GLSL shader to use for this animation.

                        For example, set it to ${fmt.code "builtins.readFile ./${name}.glsl"} to use a shader from the same directory as your configuration file.

                        See: ${fmt.bare-link "https://github.com/YaLTeR/niri/wiki/Configuration:-Animations#custom-shader"}
                      '';
                    };
                  }
                );

                actual-type = mkOptionType {
                  inherit (inner)
                    name
                    description
                    getSubOptions
                    nestedTypes
                    ;

                  check = value: builtins.isNull value || animation-kind.check value || inner.check value;
                  merge =
                    loc: defs:
                    inner.merge loc (
                      map (
                        def:
                        if builtins.isNull def.value then
                          lib.warn (obsolete-warning "${showOption loc} = null;" "${
                            showOption (loc ++ [ "enable" ])
                          } = false;" [ def ]) def
                          // {
                            value.enable = false;
                          }
                        else if animation-kind.check def.value then
                          lib.warn (rename-warning loc (loc ++ [ "kind" ]) [ def ]) def // { value.kind = def.value; }
                        else
                          def
                      ) defs
                    );
                };
              in
              optional actual-type { }
            )
          ) anims)
          {
            "<animation-kind>" = docs-only animation-kind // {
              override-loc = lib.const [ "<animation-kind>" ];
            };
          }
          (
            let
              deprecated-shaders = [
                "window-open"
                "window-close"
                "window-resize"
              ];
            in
            {
              __module =
                {
                  options,
                  config,
                  ...
                }:
                {
                  options.shaders = lib.genAttrs deprecated-shaders (
                    _: required (nullOr types.str) // { visible = false; }
                  );
                  config = lib.genAttrs deprecated-shaders (
                    name:
                    let
                      old = options.shaders.${name};
                    in
                    lib.mkIf (old.isDefined) (
                      lib.warn
                        (rename-warning (old.loc) (options.${name}.loc ++ [ "custom-shader" ]) old.definitionsWithLocations)
                        {
                          custom-shader = config.shaders.${name};
                        }
                    )
                  );
                };
            }
          )
        ];

      gestures =
        let
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

    {
      environment = attrs (nullOr types.str) // {
        description = ''
          Environment variables to set for processes spawned by niri.

          If an environment variable is already set in the environment, then it will be overridden by the value set here.

          If a value is null, then the environment variable will be unset, even if it already existed.

          Examples:

          ${fmt.nix-code-block ''
            {
              ${options.environment} = {
                QT_QPA_PLATFORM = "wayland";
                DISPLAY = null;
              };
            }
          ''}
        '';
      };
    }

    {
      window-rules =
        let
          window-rule-descriptions = rule-descriptions {
            surface = "window";
            surfaces = "windows";
            surface-rule = "window rule";
            Surface-rules = "Window rules";

            self = options.window-rules;
            spawn-at-startup = options.spawn-at-startup;

            example-fields = [
              ''
                The ${fmt.code "title"} field, when non-null, is a regular expression. It will match a window if the client has set a title and its title matches the regular expression.
              ''
              ''
                The ${fmt.code "app-id"} field, when non-null, is a regular expression. It will match a window if the client has set an app id and its app id matches the regular expression.
              ''
            ];
          };

          window-match = ordered-record' "match rule" [
            {
              app-id = nullable regex // {
                description = ''
                  A regular expression to match against the app id of the window.

                  When non-null, for this field to match a window, a client must set the app id of its window and the app id must match this regex.
                '';
              };
              title = nullable regex // {
                description = ''
                  A regular expression to match against the title of the window.

                  When non-null, for this field to match a window, a client must set the title of its window and the title must match this regex.
                '';
              };
            }
            {
              is-urgent = nullable types.bool // {
                description = ''
                  When non-null, for this field to match a window, the value must match whether the window is in the urgent state or not.

                  A window can request attention by sending an XDG activation request. Such a request can be associated with an input event (e.g. in response to you clicking a notification), in which case it will be focused right away. It can also request attention without an input event, in which case it will simply be marked as "urgent". An urgent state doesn't do anything by itself, but it can be matched on to apply a window rule only to such windows.
                '';
              };
              is-active = nullable types.bool // {
                description = ''
                  When non-null, for this field to match a window, the value must match whether the window is active or not.

                  Every monitor has up to one active window, and ${fmt.code "is-active=true"} will match the active window on each monitor. A monitor can have zero active windows if no windows are open on it. There can never be more than one active window on a monitor.
                '';
              };
              is-active-in-column = nullable types.bool // {
                description = ''
                  When non-null, for this field to match a window, the value must match whether the window is active in its column or not.

                  Every column has exactly one active-in-column window. If it is the active column, this window is also the active window. A column may not have zero active-in-column windows, or more than one active-in-column window.

                  The active-in-column window is the window that was last focused in that column. When you switch focus to a column, the active-in-column window will be the new focused window.
                '';
              };
              is-focused = nullable types.bool // {
                description = ''
                  When non-null, for this field to match a window, the value must match whether the window has keyboard focus or not.

                  A note on terminology used here: a window is actually a toplevel surface, and a surface just refers to any rectangular region that a client can draw to. A toplevel surface is just a surface with additional capabilities and properties (e.g. "fullscreen", "resizable", "min size", etc)

                  For a window to be focused, its surface must be focused. There is up to one focused surface, and it is the surface that can receive keyboard input. There can never be more than one focused surface. There can be zero focused surfaces if and only if there are zero surfaces. The focused surface does ${fmt.em "not"} have to be a toplevel surface. It can also be a layer-shell surface. In that case, there is a surface with keyboard focus but no ${fmt.em "window"} with keyboard focus.
                '';
              };
              is-floating = nullable types.bool // {
                description = ''
                  When not-null, for this field to match a window, the value must match whether the window is floating (true) or tiled (false).
                '';
              };
              is-window-cast-target = nullable types.bool // {
                description = ''
                  When non-null, matches based on whether the window is being targeted by a window cast.
                '';
              };
            }
            {
              at-startup = nullable types.bool // {
                description = window-rule-descriptions.match-at-startup;
              };
            }
          ];
        in
        list (
          ordered-record' "window rule" [
            {
              matches = list window-match // {
                description = ''
                  A list of rules to match windows.

                  If any of these rules match a window (or there are none), that window rule will be considered for this window. It can still be rejected by ${link-opt (subopts options.window-rules).excludes}

                  If all of the rules do not match a window, then this window rule will not apply to that window.
                '';
              };
            }
            {
              excludes = list window-match // {
                description = ''
                  A list of rules to exclude windows.

                  If any of these rules match a window, then this window rule will not apply to that window, even if it matches one of the rules in ${link-opt (subopts options.window-rules).matches}

                  If none of these rules match a window, then this window rule will not be rejected. It will apply to that window if and only if it matches one of the rules in ${link-opt (subopts options.window-rules).matches}
                '';
              };
            }
            {
              default-column-width = nullable default-width // {
                description = ''
                  The default width for new columns.

                  If the final value of this option is null, it default to ${link-opt (subopts options.layout).default-column-width}

                  If the final value option is not null, then its value will take priority over ${link-opt (subopts options.layout).default-column-width} for windows matching this rule.

                  An empty attrset ${fmt.code "{}"} is not the same as null. When this is set to an empty attrset ${fmt.code "{}"}, windows will get to decide their initial width. When set to null, it represents that this particular window rule has no effect on the default width (and it should instead be taken from an earlier rule or the global default).

                '';
              };
              default-window-height = nullable default-height // {
                description = ''
                  The default height for new floating windows.

                  This does nothing if the window is not floating when it is created.

                  There is no global default option for this in the layout section like for the column width. If the final value of this option is null, then it defaults to the empty attrset ${fmt.code "{}"}.

                  If this is set to an empty attrset ${fmt.code "{}"}, then it effectively "unsets" the default height for this window rule evaluation, as opposed to ${fmt.code "null"} which doesn't change the value at all. Future rules may still set it to a value and unset it again as they wish.

                  If the final value of this option is an empty attrset ${fmt.code "{}"}, then the client gets to decide the height of the window.

                  If the final value of this option is not an empty attrset ${fmt.code "{}"}, and the window spawns as floating, then the window will be created with the specified height.
                '';
              };
              default-column-display =
                nullable (enum [
                  "normal"
                  "tabbed"
                ])
                // {
                  description = ''
                    When this window is inserted into the tiling layout such that a new column is created (e.g. when it is first opened, when it is expelled from an existing column, when it's moved to a new workspace, etc), this setting controls the default display mode of the column.

                    If the final value of this field is null, then the default display mode is taken from ${link-opt (subopts options.layout).default-column-display}.
                  '';
                };
            }
            {
              open-on-output = nullable types.str // {
                description = ''
                  The output to open this window on.

                  If final value of this field is an output that exists, the new window will open on that output.

                  If the final value is an output that does not exist, or it is null, then the window opens on the currently focused output.
                '';
              };
              open-on-workspace = nullable types.str // {
                description = ''
                  The workspace to open this window on.

                  If the final value of this field is a named workspace that exists, the window will open on that workspace.

                  If the final value of this is a named workspace that does not exist, or it is null, the window opens on the currently focused workspace.
                '';
              };
              open-maximized = nullable types.bool // {
                description = ''
                  Whether to open this window in a maximized column.

                  If the final value of this field is null or false, then the window will not open in a maximized column.

                  If the final value of this field is true, then the window will open in a maximized column.
                '';
              };
              open-fullscreen = nullable types.bool // {
                description = ''
                  Whether to open this window in fullscreen.

                  If the final value of this field is true, then this window will always be forced to open in fullscreen.

                  If the final value of this field is false, then this window is never allowed to open in fullscreen, even if it requests to do so.

                  If the final value of this field is null, then the client gets to decide if this window will open in fullscreen.
                '';
              };
              open-floating = nullable types.bool // {
                description = ''
                  Whether to open this window as floating.

                  If the final value of this field is true, then this window will always be forced to open as floating.

                  If the final value of this field is false, then this window is never allowed to open as floating.

                  If the final value of this field is null, then niri will decide whether to open the window as floating or as tiled.
                '';
              };

              open-focused = nullable types.bool // {
                description = ''
                  Whether to focus this window when it is opened.

                  If the final value of this field is null, then the window will be focused based on several factors:

                  ${fmt.list [
                    "If it provided a valid activation token that hasn't expired, it will be focused."
                    "If the strict activation policy is enabled (not by default), the procedure ends here. It will be focused if and only if the activation token is valid."
                    "Otherwise, if no valid activation token was presented, but the window is a dialog, it will open next to its parent and be focused anyways."
                    "If the window is not a dialog, it will be focused if there is no fullscreen window; we don't want to steal its focus unless a dialog belongs to it."
                  ]}

                  (a dialog here means a toplevel surface that has a non-null parent)

                  If the final value of this field is not null, all of the above is ignored. Whether the window provides an activation token or not, doesn't matter. The window will be focused if and only if this field is true. If it is false, the window will not be focused, even if it provides a valid activation token.
                '';
              };
            }
            {
              block-out-from =
                nullable (enum [
                  "screencast"
                  "screen-capture"
                ])
                // {
                  description = window-rule-descriptions.block-out-from;
                };

              geometry-corner-radius = geometry-corner-radius-rule // {
                description = ''
                  The corner radii of the window decorations (border, focus ring, and shadow) in logical pixels.

                  By default, the actual window surface will be unaffected by this.

                  Set ${link-opt (subopts options.window-rules).clip-to-geometry} to true to clip the window to its visual geometry, i.e. apply the corner radius to the window surface itself.
                '';
              };

              clip-to-geometry = nullable types.bool // {
                description = ''
                  Whether to clip the window to its visual geometry, i.e. whether the corner radius should be applied to the window surface itself or just the decorations.
                '';
              };

              border = border-rule {
                name = "border";
                window = "matched window";
                description = ''
                  See ${link-opt (subopts options.layout).border}.
                '';
              };
              focus-ring = border-rule {
                name = "focus ring";
                window = "matched window with focus";
                description = ''
                  See ${link-opt (subopts options.layout).focus-ring}.
                '';
              };

              tab-indicator =
                let
                  layout-tab-indicator = subopts (subopts options.layout).tab-indicator;
                in
                section' (
                  { options, ... }:
                  {
                    options = make-decoration-options options {
                      urgent.description = ''
                        See ${link-opt layout-tab-indicator.urgent}.
                      '';
                      active.description = ''
                        See ${link-opt layout-tab-indicator.active}.
                      '';
                      inactive.description = ''
                        See ${link-opt layout-tab-indicator.inactive}.
                      '';
                    };
                  }
                );

              shadow = shadow-rule;
              draw-border-with-background = nullable types.bool // {
                description = ''
                  Whether to draw the focus ring and border with a background.

                  Normally, for windows with server-side decorations, niri will draw an actual border around them, because it knows they will be rectangular.

                  Because client-side decorations can take on arbitrary shapes, most notably including rounded corners, niri cannot really know the "correct" place to put a border, so for such windows it will draw a solid rectangle behind them instead.

                  For most windows, this looks okay. At worst, you have some uneven/jagged borders, instead of a gaping hole in the region outside of the corner radius of the window but inside its bounds.

                  If you wish to make windows sucha s your terminal transparent, and they use CSD, this is very undesirable. Instead of showing your wallpaper, you'll get a solid rectangle.

                  You can set this option per window to override niri's default behaviour, and instruct it to omit the border background for CSD windows. You can also explicitly enable it for SSD windows.
                '';
              };
              opacity = nullable types.float // {
                description = window-rule-descriptions.opacity;
              };
            }
            (
              let
                sizing-info = bound: ''
                  Sets the ${bound} (in logical pixels) that niri will ever ask this window for.

                  Keep in mind that the window itself always has a final say in its size, and may not respect the ${bound} set by this option.
                '';

                sizing-opt =
                  bound:
                  nullable types.int
                  // {
                    description = sizing-info bound;
                  };
              in
              {
                min-width = sizing-opt "minimum width";
                max-width = sizing-opt "maximum width";
                min-height = sizing-opt "minimum height";
                max-height = nullable types.int // {
                  description = ''
                    ${sizing-info "maximum height"}

                    Also, note that the maximum height is not taken into account when automatically sizing columns. That is, when a column is created normally, windows in it will be "automatically sized" to fill the vertical space. This algorithm will respect a minimum height, and not make windows any smaller than that, but the max height is only taken into account if it is equal to the min height. In other words, it will only accept a "fixed height" or a "minimum height". In practice, most windows do not set a max size unless it is equal to their min size, so this is usually not a problem without window rules.

                    If you manually change the window heights, then max-height will be taken into account and restrict you from making it any taller, as you'd intuitively expect.
                  '';
                };
              }
            )
            {
              baba-is-float = nullable types.bool // {
                description = ''
                  Makes your window FLOAT up and down, like in the game Baba Is You.

                  Made for April Fools 2025.
                '';
              };
              default-floating-position =
                nullable (record {
                  x = required float-or-int;
                  y = required float-or-int;
                  relative-to = required (enum [
                    "top-left"
                    "top-right"
                    "bottom-left"
                    "bottom-right"
                    "top"
                    "bottom"
                    "left"
                    "right"
                  ]);
                })
                // {
                  description = ''
                    The default position for this window when it enters the floating layout.

                    If a window is created as floating, it will be placed at this position.

                    If a window is created as tiling, then later made floating, it will be placed at this position.

                    If a window has already been placed as floating through one of the above methods, and moved back to the tiling layout, then this option has no effect the next time it enters the floating layout. It will be placed at the same position it was last time.

                    The ${fmt.code "x"} and ${fmt.code "y"} fields are the distances from the edge of the screen to the edge of the window, in logical pixels. The ${fmt.code "relative-to"} field determines which two edges of the window and screen that these distances are measured from.
                  '';
                };
            }
            {
              variable-refresh-rate = nullable types.bool // {
                description = ''
                  Takes effect only when the window is on an output with ${link-opt (subopts options.outputs).variable-refresh-rate} set to ${fmt.code ''"on-demand"''}. If the final value of this field is true, then the output will enable variable refresh rate when this window is present on it.
                '';
              };
            }
            {
              scroll-factor = nullable float-or-int;
            }
            {
              tiled-state = nullable types.bool;
            }
          ]
        )
        // {
          description = window-rule-descriptions.top-option;
        };
    }

    {
      layer-rules =
        let
          layer-rule-descriptions = rule-descriptions {
            surface = "layer surface";
            surfaces = "layer surfaces";
            surface-rule = "layer rule";
            Surface-rules = "Layer rules";

            self = options.layer-rules;
            spawn-at-startup = options.spawn-at-startup;

            example-fields = [
              ''
                The ${fmt.code "namespace"} field, when non-null, is a regular expression. It will match a layer surface for which the client has set a namespace that matches the regular expression.
              ''
            ];
          };

          layer-match = ordered-record' "match rule" [
            {
              namespace = nullable regex // {
                description = ''
                  A regular expression to match against the namespace of the layer surface.

                  All layer surfaces have a namespace set once at creation. When this rule is non-null, the regex must match the namespace of the layer surface for this rule to match.
                '';
              };
            }
            {
              at-startup = nullable types.bool // {
                description = layer-rule-descriptions.match-at-startup;
              };
            }
          ];
        in
        list (
          ordered-record' "layer rule" [
            {
              matches = list layer-match // {
                description = layer-rule-descriptions.match;
              };
            }
            {
              excludes = list layer-match // {
                description = layer-rule-descriptions.exclude;
              };
            }
            {
              block-out-from =
                nullable (enum [
                  "screencast"
                  "screen-capture"
                ])
                // {
                  description = layer-rule-descriptions.block-out-from;
                };

              opacity = nullable types.float // {
                description = layer-rule-descriptions.opacity;
              };
            }
            {
              shadow = shadow-rule;
              geometry-corner-radius = geometry-corner-radius-rule // {
                description = ''
                  The corner radii of the surface decorations (shadow) in logical pixels.
                '';
              };
            }
            {
              place-within-backdrop = nullable types.bool // {
                description = ''
                  Set to ${fmt.code "true"} to place the surface into the backdrop visible in the Overview and between workspaces.
                  This will only work for background layer surfaces that ignore exclusive zones (typical for wallpaper tools). Layers within the backdrop will ignore all input.
                '';
              };

              baba-is-float = nullable types.bool // {
                description = ''
                  Make your layer surfaces FLOAT up and down.

                  This is a natural extension of the April Fools' 2025 feature.
                '';
              };
            }
          ]
        )
        // {
          description = layer-rule-descriptions.top-option;
        };
    }

    {
      xwayland-satellite =
        section {
          enable = optional types.bool true;
          path = nullable types.str // {
            description = ''
              Path to the xwayland-satellite binary.

              Set it to something like ${fmt.code "lib.getExe pkgs.xwayland-satellite-unstable"}.
            '';
          };
        }
        // {
          description = ''
            Xwayland-satellite integration. Requires unstable niri and unstable xwayland-satellite.
          '';
        };
    }

    {
      debug = attrs kdl.types.kdl-args // {
        description = ''
          Debug options for niri.

          ${fmt.code "kdl arguments"} in the type refers to a list of arguments passed to a node under the ${fmt.code "debug"} section. This is a way to pass arbitrary KDL-valid data to niri. See ${link-opt (subopts options.binds).action} for more information on all the ways you can use this.

          Note that for no-argument nodes, there is no special way to define them here. You can't pass them as just a "string" because that makes no sense here. You must pass it an empty array of arguments.

          Here's an example of how to use this:

          ${fmt.nix-code-block ''
            {
              ${options.debug} = {
                disable-cursor-plane = [];
                render-drm-device = "/dev/dri/renderD129";
              };
            }
          ''}

          This option is, just like ${link-opt (subopts options.binds).action}, not verified by the nix module. But, it will be validated by niri before committing the config.

          Additionally, i don't guarantee stability of the debug options. They may change at any time without prior notice, either because of niri changing the available options, or because of me changing this to a more reasonable schema.
        '';
      };
    }
  ];
}
