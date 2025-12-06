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
  inherit (lib.types) nullOr;
  inherit (niri-flake-internal)
    fmt
    section'
    nullable
    section
    list
    attrs
    optional
    ;
in
[
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
                  ${toplevel-options.spawn-at-startup} = [
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
                  ${toplevel-options.spawn-at-startup} = [
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
    environment = attrs (nullOr types.str) // {
      description = ''
        Environment variables to set for processes spawned by niri.

        If an environment variable is already set in the environment, then it will be overridden by the value set here.

        If a value is null, then the environment variable will be unset, even if it already existed.

        Examples:

        ${fmt.nix-code-block ''
          {
            ${toplevel-options.environment} = {
              QT_QPA_PLATFORM = "wayland";
              DISPLAY = null;
            };
          }
        ''}
      '';
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
]
