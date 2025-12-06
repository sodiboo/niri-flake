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
    ;
  inherit (lib.types) nullOr enum;
  inherit (niri-flake-internal)
    fmt
    link-opt
    subopts
    section'
    make-ordered-options
    nullable
    float-or-int
    section
    record
    required
    shadow-descriptions
    list
    attrs
    attrs-record
    optional
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
      outputs = import ./outputs.nix {
        inherit
          lib
          kdl
          niri-flake-internal
          toplevel-options
          ;
      };
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
      animations = import ./animations.nix {
        inherit
          lib
          kdl
          niri-flake-internal
          toplevel-options
          ;
      };

      gestures = import ./gestures.nix {
        inherit
          lib
          kdl
          niri-flake-internal
          toplevel-options
          ;
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

    (import ./surface-rules.nix {
      inherit
        lib
        kdl
        niri-flake-internal
        toplevel-options
        ;
    })

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
