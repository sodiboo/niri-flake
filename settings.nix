{
  inputs,
  kdl,
  lib,
  docs,
  binds,
  ...
}:
with lib;
with docs.lib; rec {
  module = let
    inherit (types) nullOr attrsOf listOf submodule enum either;

    binds-stable = binds inputs.niri-stable;
    binds-unstable = binds inputs.niri-unstable;

    binds-for = groupBy (name:
      if binds-stable ? ${name} && binds-unstable ? ${name}
      then "both"
      else if binds-stable ? ${name}
      then "stable"
      else if binds-unstable ? ${name}
      then "unstable"
      else abort "unreachable") (attrNames (binds-stable // binds-unstable));

    record = options: let base = submodule {inherit options;}; in mkOptionType {
      name = "record";
      inherit (base) description check merge nestedTypes getSubOptions;
    };

    required = type: mkOption {inherit type;};
    nullable = type: optional (nullOr type) null;
    optional = type: default: mkOption {inherit type default;};

    attrs = type: optional (attrsOf type) {};
    list = type: optional (listOf type) [];

    variant = variants:
      mkOptionType {
        name = "variant";
        description =
          if variants == {}
          then "impossible (empty variant)"
          else "variant of: ${concatStringsSep " | " (attrNames variants)}";
        descriptionClass =
          if variants == {}
          then "noun"
          else "composite";

        check = v: let
          names = attrNames v;
          name = head names;
        in
          isAttrs v && length names == 1 && elem name (attrNames variants) && variants.${name}.check v.${name};

        merge = loc: definitions: let
          defs-for = name:
            pipe definitions [
              (filter (hasAttrByPath ["value" name]))
              (map (def: def // {value = def.value.${name};}))
            ];
          merged = mapAttrs (name: type:
            type.merge (loc ++ [name]) (defs-for name))
          (filterAttrs (name: type: defs-for name != []) variants);
        in
          if merged == {}
          then throw "The option `${showOption loc}` has no definitions, but one is required"
          else if length (attrNames merged) == 1
          then merged
          else throw "The option `${showOption loc}` has conflicting definitions of multiple variants";

        nestedTypes = variants;

        getSubOptions =
          (record (mapAttrs (const (type:
            (required type)
            // (optionalAttrs (type ? variant-description) {
              description = type.variant-description;
            })))
          variants))
          .getSubOptions;
      };

    basic-pointer = default-natural-scroll: {
      natural-scroll =
        optional types.bool default-natural-scroll
        // {
          description = ''
            Whether scrolling should move the content in the scrolled direction (as opposed to moving the viewport)

            Further reading:
            - ${libinput-link "configuration" "Scrolling"}
            - ${libinput-link "scrolling" "Natural scrolling vs. traditional scrolling"}
          '';
        };
      accel-speed =
        optional types.float 0.0
        // {
          description = ''
            Further reading:
            - ${libinput-link "configuration" "Pointer acceleration"}
          '';
        };
      accel-profile =
        nullable (enum ["adaptive" "flat"])
        // {
          description = ''
            Further reading:
            - ${libinput-link "pointer-acceleration" "Pointer acceleration profiles"}
          '';
        };
    };

    preset-width = variant {
      fixed =
        types.int
        // {
          variant-description = ''
            The width of the column in logical pixels
          '';
        };
      proportion =
        types.float
        // {
          variant-description = ''
            The width of the column as a proportion of the screen's width
          '';
        };
    };

    emptyOr = elemType:
      mkOptionType {
        name = "emptyOr";
        description =
          if elem elemType.descriptionClass ["noun" "conjunction"]
          then "{} or ${elemType.description}"
          else "{} or (${elemType.description})";
        descriptionClass = "conjunction";
        check = v: v == {} || elemType.check v;
        nestedTypes.elemType = elemType;
        merge = loc: defs:
          if all (def: def.value == {}) defs
          then {}
          else elemType.merge loc defs;

        inherit (elemType) getSubOptions;
      };

    default-width = emptyOr preset-width;

    # niri seems to have deprecated this way of defining colors; so we won't support it
    # color-array = mkOptionType {
    #   name = "color";
    #   description = "[red green blue alpha]";
    #   descriptionClass = "noun";
    #   check = v: isList v && length v == 4 && all isInt v;
    # };

    gradient = record {
      from = required types.str;
      to = required types.str;
      angle = optional types.int 180;
      relative-to = optional (enum ["window" "workspace-view"]) "window";
    };

    borderish = default-active-color: {
      width = optional types.int 4;
      active-color = optional types.str default-active-color;
      inactive-color = optional types.str "rgb(80 80 80)";
      active-gradient = nullable gradient;
      inactive-gradient = nullable gradient;
    };

    match = record {
      app-id = nullable types.str;
      title = nullable types.str;
    };

    ordered-record = sections: let
      base = record (concatMapAttrs (flip const) sections);
      self = mkOptionType {
        inherit (base) name description check merge nestedTypes;
        getSubOptions = loc: mapAttrs (section: opts: (record opts).getSubOptions loc) sections;
      };
    in
      self;

    make-section = flip optional {};

    make-ordered = flip pipe [
      (imap0 (i: section: {
        name = elemAt strings.lowerChars i;
        value = section;
      }))
      listToAttrs
      ordered-record
    ];

    section = flip pipe [record make-section];
    # ordered-section = flip pipe [make-ordered make-section];

    settings = make-ordered [
      {
        binds =
          attrs (either types.str kdl.types.kdl-leaf)
          // {
            description = ''
              Keybindings for niri.

              This is a mapping of keybindings to "actions".

              An action is an attrset with a single key, being the name, and a value that is a list of its arguments. For example, to represent a spawn action, you could do this:

              ```nix
              {
                programs.niri.settings.binds = {
                  "XF86AudioRaiseVolume".spawn = ["wpctl" "set-volume" "@DEFAULT_AUDIO_SINK@" "0.1+"];
                  "XF86AudioLowerVolume".spawn = ["wpctl" "set-volume" "@DEFAULT_AUDIO_SINK@" "0.1-"];
                };
              }
              ```

              If there is only a single argument, you can pass it directly. It will be implicitly converted to a list in that case.

              ```nix
              {
                programs.niri.settings.binds = {
                  "Mod+D".spawn = "fuzzel";
                  "Mod+1".focus-workspace = 1;
                };
              }
              ```

              For actions taking properties (named arguments), you can pass an attrset.

              ```nix
              {
                programs.niri.settings.binds = {
                  "Mod+Shift+E".quit.skip-confirmation = true;
                };
              }
              ```

              There is also a `binds` attrset available under each of the packages from this flake. It has attributes for each action.

              > [!note]
              > Note that although this interface is stable, its location is *not* stable. I've only just implemented this "magic leaf" kind of varargs function. I put it under each package for now, but that may change in the near future.

              Usage is like so:

              ```nix
              {
                programs.niri.settings.binds = with config.programs.niri.package.binds; {
                  "XF86AudioRaiseVolume" = spawn "wpctl" "set-volume" "@DEFAULT_AUDIO_SINK@" "0.1+";
                  "XF86AudioLowerVolume" = spawn "wpctl" "set-volume" "@DEFAULT_AUDIO_SINK@" "0.1-";

                  "Mod+D" = spawn "fuzzel";
                  "Mod+1" = focus-workspace 1;

                  "Mod+Shift+E" = quit;
                  "Mod+Ctrl+Shift+E" = quit { skip-confirmation=true; };

                  "Mod+Plus" = set-column-width "+10%";
                }
              }
              ```

              These are the available actions:

              ${concatStringsSep "\n" (concatLists [
                (forEach binds-for.both or [] (a: "- `${a}`"))
                (forEach binds-for.stable or [] (a: "- `${a}` (only on `niri-stable`)"))
                (forEach binds-for.unstable or [] (a: "- `${a}` (only on `niri-unstable`)"))
              ])}

              No distinction is made between actions that take arguments and those that don't. Their usages are the exact same.
            '';
          };
      }

      {
        screenshot-path =
          optional (nullOr types.str) "~/Pictures/Screenshots/Screenshot from %Y-%m-%d %H-%M-%S.png"
          // {
            description = ''
              The path to save screenshots to.

              If this is null, then no screenshots will be saved.

              If the path starts with a `~`, then it will be expanded to the user's home directory.

              The path is then passed to [`stftime(3)`](https://man7.org/linux/man-pages/man3/strftime.3.html) with the current time, and the result is used as the final path.
            '';
          };
      }

      {
        hotkey-overlay.skip-at-startup =
          optional types.bool false
          // {
            description = ''
              Whether to skip the hotkey overlay shown when niri starts.
            '';
          };
      }

      {
        prefer-no-csd =
          optional types.bool false
          // {
            description = ''
              Whether to prefer server-side decorations (SSD) over client-side decorations (CSD).
            '';
          };
      }

      {
        spawn-at-startup = list (record {
          command = list types.str;
        });
      }

      {
        input = {
          keyboard = {
            xkb = let
              arch-man-xkb = anchor: "[`xkeyboard-config(7)`](https://man.archlinux.org/man/xkeyboard-config.7#${anchor})";

              default-env = default: field: ''
                If this is set to ${default}, the ${field} will be read from the `XKB_DEFAULT_${toUpper field}` environment variable.
              '';

              str-fallback = default-env "an empty string";
              nullable-fallback = default-env "null";

              base = {
                # niri doesn't default its config repr to "us", but it is Option<String>
                # however, when passed to xkb, it needs to be &str (None is not allowed)
                # and there, niri will `.unwrap_or("us")`
                # https://github.com/YaLTeR/niri/blob/0c57815fbf47c69af9ed11fa8ebc1b52158a3ba2/niri-config/src/lib.rs#L106
                layout =
                  optional types.str "us"
                  // {
                    description = ''
                      A comma-separated list of layouts (languages) to include in the keymap.

                      Note that niri will set this to `"us"` by default, when unspecified.

                      See ${arch-man-xkb "LAYOUTS"} for a list of available layouts and their variants.

                      ${str-fallback "layout"}
                    '';
                  };
                model =
                  optional types.str ""
                  // {
                    description = ''
                      The keyboard model by which to interpret keycodes and LEDs

                      See ${arch-man-xkb "MODELS"} for a list of available models.

                      ${str-fallback "model"}
                    '';
                  };
                rules =
                  optional types.str ""
                  // {
                    description = ''
                      The rules file to use.

                      The rules file describes how to interpret the values of the model, layout, variant and options fields.

                      ${str-fallback "rules"}
                    '';
                  };
                variant =
                  optional types.str ""
                  // {
                    description = ''
                      A comma separated list of variants, one per layout, which may modify or augment the respective layout in various ways.

                      See ${arch-man-xkb "LAYOUTS"} for a list of available variants for each layout.

                      ${str-fallback "variant"}
                    '';
                  };
                options =
                  nullable types.str
                  // {
                    description = ''
                      A comma separated list of options, through which the user specifies non-layout related preferences, like which key combinations are used for switching layouts, or which key is the Compose key.

                      See ${arch-man-xkb "OPTIONS"} for a list of available options.

                      If this is set to an empty string, no options will be used.

                      ${nullable-fallback "options"}
                    '';
                  };
              };
              # base' = mapAttrs (name: opt: opt // optionalAttrs (opt.default == "" || opt.default == null) {defaultText = "${if opt.default == "" then "\"\"" else "null"} (inherited from XKB_DEFAULT_${toUpper name}>";}) base;
            in
              section base
              // {
                description = ''
                  Parameters passed to libxkbcommon, which handles the keyboard in niri.

                  Further reading:
                  - [`smithay::wayland::seat::XkbConfig`](https://docs.rs/smithay/latest/smithay/wayland/seat/struct.XkbConfig.html)
                '';
              };
            repeat-delay =
              optional types.int 600
              // {
                description = ''
                  The delay in milliseconds before a key starts repeating.
                '';
              };
            repeat-rate =
              optional types.int 25
              // {
                description = ''
                  The rate in characters per second at which a key repeats.
                '';
              };
            track-layout =
              optional (enum ["global" "window"]) "global"
              // {
                description = ''
                  The keyboard layout can be remembered per `"window"`, such that when you switch to a window, the keyboard layout is set to the one that was last used in that window.

                  By default, there is only one `"global"` keyboard layout and changing it in any window will affect the keyboard layout used in all other windows too.
                '';
              };
          };
          touchpad =
            (basic-pointer true)
            // {
              tap =
                optional types.bool true
                // {
                  description = ''
                    Whether to enable tap-to-click.

                    Further reading:
                    - ${libinput-link "configuration" "Tap-to-click"}
                    - ${libinput-link "tapping" "Tap-to-click behaviour"}
                  '';
                };
              dwt =
                optional types.bool false
                // {
                  description = ''
                    Whether to disable the touchpad while typing.

                    Further reading:
                    - ${libinput-link "configuration" "Disable while typing"}
                    - ${libinput-link "palm-detection" "Disable-while-typing"}
                  '';
                };
              dwtp =
                optional types.bool false
                // {
                  description = ''
                    Whether to disable the touchpad while the trackpoint is in use.

                    Further reading:
                    - ${libinput-link "configuration" "Disable while trackpointing"}
                    - ${libinput-link "palm-detection" "Disable-while-trackpointing"}
                  '';
                };
              tap-button-map =
                nullable (enum ["left-middle-right" "left-right-middle"])
                // {
                  description = ''
                    The mouse button to register when tapping with 1, 2, or 3 fingers, when ${link' "programs.niri.settings.input.touchpad.tap"} is enabled.

                    Further reading:
                    - ${libinput-link "configuration" "Tap-to-click"}
                  '';
                };
              click-method =
                nullable (enum ["button-areas" "clickfinger"])
                // {
                  description = ''
                    ${unstable-note}

                    Method to determine which mouse button is pressed when you click the touchpad.

                    - `"button-areas"`: ${libinput-doc "clickpad-softbuttons" "Software button areas"} \
                      The button is determined by which part of the touchpad was clicked.

                    - `"clickfinger"`: ${libinput-doc "clickpad-softbuttons" "Clickfinger behavior"} \
                      The button is determined by how many fingers clicked.

                    Further reading:
                    - ${libinput-link "configuration" "Click method"}
                    - ${libinput-link "clickpad-softbuttons" "Clickpad software button behavior"}
                  '';
                };
            };
          mouse = basic-pointer false;
          trackpoint = basic-pointer false;
          tablet.map-to-output = nullable types.str;
          touch.map-to-output = nullable types.str;

          power-key-handling.enable =
            optional types.bool true
            // {
              description = ''
                By default, niri will take over the power button to make it sleep instead of power off.

                You can disable this behaviour if you prefer to configure the power button elsewhere.
              '';
            };
        };
      }

      {
        outputs = attrs (record {
          enable = optional types.bool true;
          scale =
            optional types.float 1.0
            // {
              description = ''
                The scale of this output, which represents how many physical pixels fit in one logical pixel.

                Although this is a floating-point number, niri currently only accepts integer values. It does not support fractional scaling.
              '';
            };
          transform = {
            flipped =
              optional types.bool false
              // {
                description = ''
                  Whether to flip this output vertically.
                '';
              };
            rotation =
              optional (enum [0 90 180 270]) 0
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
              refresh =
                nullable types.float
                // {
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
        });
      }

      {
        cursor = {
          theme = optional types.str "default";
          size = optional types.int 24;
        };
      }

      {
        layout = {
          focus-ring =
            (borderish "rgb(127 200 255)")
            // {
              enable = optional types.bool true;
            };

          border =
            (borderish "rgb(255 200 127)")
            // {
              enable = optional types.bool false;
            };
          preset-column-widths =
            list preset-width
            // {
              description = ''
                The widths that `switch-preset-column-width` will cycle through.

                Each width can either be a fixed width in logical pixels, or a proportion of the screen's width.

                Example:

                ```nix
                {
                  programs.niri.settings.layout.preset-coumn-widths = [
                    { proportion = 1./3.; }
                    { proportion = 1./2.; }
                    { proportion = 2./3.; }

                    # { fixed = 1920; }
                  ];
                }
                ```
              '';
            };
          default-column-width =
            optional default-width {}
            // {
              description = ''
                The default width for new columns.

                When this is set to an empty attrset `{}`, windows will get to decide their initial width. This is not null, such that it can be distinguished from window rules that don't touch this

                See ${link' "programs.niri.settings.layout.preset-column-widths"} for more information.

                You can override this for specific windows using ${link' "programs.niri.settings.window-rules.*.default-column-width"}
              '';
            };
          center-focused-column =
            optional (enum ["never" "always" "on-overflow"]) "never"
            // {
              description = ''
                When changing focus, niri can automatically center the focused column.

                - `"never"`: If the focused column doesn't fit, it will be aligned to the edges of the screen.
                - `"on-overflow"`: if the focused column doesn't fit, it will be centered on the screen.
                - `"always"`: the focused column will always be centered, even if it was already fully visible.
              '';
            };
          gaps =
            optional types.int 16
            // {
              description = ''
                The gap between windows in the layout, measured in logical pixels.
              '';
            };
          struts =
            section {
              left = optional types.int 0;
              right = optional types.int 0;
              top = optional types.int 0;
              bottom = optional types.int 0;
            }
            // {
              description = ''
                The distances from the edges of the screen to the eges of the working area.

                The top and bottom struts are absolute gaps from the edges of the screen. If you set a bottom strut of 64px and the scale is 2.0, then the output will have 128 physical pixels under the scrollable working area where it only shows the wallpaper.

                Struts are computed in addition to layer-shell surfaces. If you have a waybar of 32px at the top, and you set a top strut of 16px, then you will have 48 logical pixels from the actual edge of the display to the top of the working area.

                The left and right structs work in a similar way, except the padded space is not empty. The horizontal struts are used to constrain where focused windows are allowed to go. If you define a left strut of 64px and go to the first window in a workspace, that window will be aligned 64 logical pixels from the left edge of the output, rather than snapping to the actual edge of the screen. If another window exists to the left of this window, then you will see 64px of its right edge (if you have zero borders and gaps)
              '';
            };
        };
      }

      {
        animations = let
          animation = variant {
            spring = record {
              damping-ratio = required types.float;
              stiffness = required types.int;
              epsilon = required types.float;
            };
            easing = record {
              duration-ms = required types.int;
              curve = required (enum ["ease-out-cubic" "ease-out-expo"]);
            };
          };
          opts = {
            enable = optional types.bool true;
            slowdown = optional types.float 1.0;
          };

          defaults = {
            workspace-switch.spring = {
              damping-ratio = 1.0;
              stiffness = 1000;
              epsilon = 0.0001;
            };
            horizontal-view-movement.spring = {
              damping-ratio = 1.0;
              stiffness = 800;
              epsilon = 0.0001;
            };
            config-notification-open-close.spring = {
              damping-ratio = 0.6;
              stiffness = 1000;
              epsilon = 0.001;
            };
            window-open.easing = {
              duration-ms = 150;
              curve = "ease-out-expo";
            };
          };

          anims =
            mapAttrs (const (
              optional (nullOr (animation
                // {
                  description = "animation";
                  descriptionClass = "noun";
                  getSubOptions = const {};
                }))
            ))
            defaults;
          base = record (opts // anims);
        in
          make-section (mkOptionType {
            inherit (base) name check merge nestedTypes;
            description = "animations";
            descriptionClass = "noun";
            getSubOptions = loc: {
              a.opts = (record opts).getSubOptions loc;
              b.submodule =
                (required (animation
                  // {
                    description = "animation";
                    nestedTypes.newtype-inner = animation;
                  }))
                // {
                  defaultText = null;
                  loc = loc ++ ["<name>"];
                };
              c.defaults = {
                anims = (record anims).getSubOptions loc;
              };
            };
          });
      }

      {
        environment =
          attrs (nullOr (types.str))
          // {
            description = ''
              Environment variables to set for processes spawned by niri.

              If an environment variable is already set in the environment, then it will be overridden by the value set here.

              If a value is null, then the environment variable will be unset, even if it already existed.

              Examples:

              ```nix
              {
                programs.niri.settings.environment = {
                  QT_QPA_PLATFORM = "wayland";
                  DISPLAY = null;
                };
              }
              ```
            '';
          };
      }

      {
        window-rules =
          list (make-ordered [
            {
              matches =
                list match
                // {
                  description = ''
                    A list of rules to match windows.

                    If any of these rules match a window (or there are none), that window rule will be considered for this window. It can still be rejected by ${link' "programs.niri.settings.window-rules.*.excludes"}

                    If all of the rules do not match a window, then this window rule will not apply to that window.
                  '';
                };
            }
            {
              excludes =
                list match
                // {
                  description = ''
                    A list of rules to exclude windows.

                    If any of these rules match a window, then this window rule will not apply to that window, even if it matches one of the rules in ${link' "programs.niri.settings.window-rules.*.matches"}

                    If none of these rules match a window, then this window rule will not be rejected. It will apply to that window if and only if it matches one of the rules in ${link' "programs.niri.settings.window-rules.*.matches"}
                  '';
                };
            }
            {
              default-column-width =
                nullable default-width
                // {
                  description = ''
                    By default, when this option is null, then this window rule will not affect the default column width. If none of the applicable window rules have a nonnull value, it will be gotten from ${link' "programs.niri.settings.layout.default-column-width"}

                    If this option is not null, then its value will take priority over ${link' "programs.niri.settings.layout.default-column-width"} for windows matching this rule.

                    As a reminder, an empty attrset `{}` is not the same as null. Here, null represents that this window rule has no effect on the default width, wheras `{}` represents "let the client choose".
                  '';
                };
              open-on-output =
                nullable types.str
                // {
                  description = ''
                    The output to open this window on.

                    If final value of this field is an output that exists, the new window will open on that output.

                    If the final value is an output that does not exist, or it is null, then the window opens on the currently focused output.
                  '';
                };
              open-maximized =
                nullable types.bool
                // {
                  description = ''
                    Whether to open this window in a maximized column.

                    If the final value of this field is null or false, then the window will not open in a maximized column.

                    If the final value of this field is true, then the window will open in a maximized column.
                  '';
                };
              open-fullscreen =
                nullable types.bool
                // {
                  description = ''
                    Whether to open this window in fullscreen.

                    If the final value of this field is true, then this window will always be forced to open in fullscreen.

                    If the final value of this field is false, then this window is never allowed to open in fullscreen, even if it requests to do so.

                    If the final value of this field is null, then the client gets to decide if this window will open in fullscreen.
                  '';
                };
            }
          ])
          // {
            description = ''
              Window rules.

              A window rule will match based on ${link' "programs.niri.settings.window-rules.*.matches"} and ${link' "programs.niri.settings.window-rules.*.excludes"}. Both of these are lists of "match rules".

              A given match rule can match based on the `title` or `app-id` fields. For a given match rule to "match" a window, it must match on all fields.

              - The `title` field, when non-null, is a regular expression. It will match a window if the client has set a title and its title matches the regular expression.

              - The `app-id` field, when non-null, is a regular expression. It will match a window if the client has set an app id and its app id matches the regular expression.

              - If a field is null, it will always match.

              For a given window rule to match a window, the above logic is employed to determine whether any given match rule matches, and the interactions between them decide whether the window rule as a whole will match. For a given window rule:

              - A given window is "considered" if any of the match rules in ${link' "programs.niri.settings.window-rules.*.matches"} successfully match this window. If all of the match rules do not match this window, then that window will never match this window rule.

              - If ${link' "programs.niri.settings.window-rules.*.matches"} contains no match rules, it will match any window and "consider" it for this window rule.

              - If a given window is "considered" for this window rule according to the above rules, the selection can be further refined with ${link' "programs.niri.settings.window-rules.*.excludes"}. If any of the match rules in `excludes` match this window, it will be rejected and this window rule will not match the given window.

              That is, a given window rule will apply to a given window if any of the entries in ${link' "programs.niri.settings.window-rules.*.matches"} match that window (or there are none), AND none of the entries in ${link' "programs.niri.settings.window-rules.*.excludes"} match that window.

              All fields of a window rule can be set to null, which represents that the field shall have no effect on the window (and in general, the client is allowed to choose the initial value).

              To compute the final set of window rules that apply to a given window, each window rule in this list is consdered in order.

              At first, every field is set to null.

              Then, for each applicable window rule:

              - If a given field is null on this window rule, it has no effect. It does nothing and "inherits" the value from the previous rule.
              - If the given field is not null, it will overwrite the value from any previous rule.

              The "final value" of a field is simply its value at the end of this process. That is, the final value of a field is the one from the *last* window rule that matches the given window rule (not considering null entries, unless there are no non-null entries)

              If the final value of a given field is null, then it usually means that the client gets to decide. For more information, see the documentation for each field.
            '';
          };
      }

      {
        debug =
          nullable (attrsOf kdl.types.kdl-args)
          // {
            description = ''
              Debug options for niri.

              `kdl arguments` in the type refers to a list of arguments passed to a node under the `debug` section. This is a way to pass arbitrary KDL-valid data to niri. See ${link' "programs.niri.settings.binds"} for more information on all the ways you can use this.

              Note that for no-argument nodes, there is no special way to define them here. You can't pass them as just a "string" because that makes no sense here. You must pass it an empty array of arguments.

              Here's an example of how to use this:

              ```nix
              {
                programs.niri.settings.debug = {
                  disable-cursor-plane = [];
                  render-drm-device = "/dev/dri/renderD129";
                };
              }
              ```

              This option is, just like ${link' "programs.niri.settings.binds"}, not verified by the nix module. But, it will be validated by niri before committing the config.

              Additionally, i don't guarantee stability of the debug options. They may change at any time without prior notice, either because of niri changing the available options, or because of me changing this to a more reasonable schema.
            '';
          };
      }
    ];
  in
    {config, ...}: let
      cfg = config.programs.niri;
    in {
      options.programs.niri = {
        config = mkOption {
          type = types.nullOr (types.either types.str kdl.types.kdl-document);
          default = render cfg.settings;
          defaultText = null;
          description = ''
            The niri config file.

            - When this is null, no config file is generated.
            - When this is a string, it is assumed to be the config file contents.
            - When this is kdl document, it is serialized to a string before being used as the config file contents.

            By default, this is a KDL document that reflects the settings in ${link' "programs.niri.settings"}.
          '';
        };

        finalConfig = mkOption {
          type = types.nullOr types.str;
          default =
            if isString cfg.config
            then cfg.config
            else if cfg.config != null
            then kdl.serialize.nodes cfg.config
            else null;
          readOnly = true;
          defaultText = null;
          description = ''
            The final niri config file contents.

            This is a string that reflects the document stored in ${link' "programs.niri.config"}.

            It is exposed mainly for debugging purposes, such as when you need to inspect how a certain option affects the resulting config file.
          '';
        };

        settings =
          (nullable settings)
          // {
            description = ''
              Nix-native settings for niri.

              By default, when this is null, no config file is generated.

              Beware that setting ${link' "programs.niri.config"} completely overrides everything under this option.
            '';
          };
      };
    };
  fake-docs = {
    stable-tag,
    nixpkgs,
  }: {
    imports = [module];

    options._ = let
      pkg-output = name: desc:
        fake-option (pkg-header name) ''
          (where `<system>` is one of: `x86_64-linux`, `aarch64-linux`)

          ${desc}

          Note that the `aarch64-linux` package is untested. It might work, but i can't guarantee it.

          Also note that you likely should not be using these outputs directly. Instead, you should use the overlay (${link' "overlays.niri"}).
        '';

      enable-option = fake-option "programs.niri.enable" ''
        - type: `boolean`
        - default: `false`

        Whether to install and enable niri.

        This also enables the necessary system components for niri to function properly, such as desktop portals and polkit.
      '';

      package-option = fake-option "programs.niri.package" ''
        - type: `package`
        - default: ${pkg-link "niri-stable"}

        The package that niri will use.

        You may wish to set it to the following values:

        - ${nixpkgs-link "niri"}
        - ${pkg-link "niri-stable"}
        - ${pkg-link "niri-unstable"}
      '';
      link-niri-release = tag: "[release `${tag}`](https://github.com/YaLTeR/niri/releases/tag/${tag})";

      link-stylix-opt = opt: "[`${opt}`](https://danth.github.io/stylix/options/hm.html#${anchor opt})";
    in {
      a.nonmodules = {
        _ = header "Packages provided by this flake";

        a.packages = {
          niri-stable = pkg-output "niri-stable" ''
            The latest stable tagged version of niri (currently ${link-niri-release stable-tag}), along with potential patches.
          '';
          niri-unstable = pkg-output "niri-unstable" ''
            The latest commit to the main branch of niri. This is refreshed hourly and may break at any time without prior notice.
          '';
        };

        b.overlay = fake-option "overlays.niri" ''
          A nixpkgs overlay that provides `niri-stable` and `niri-unstable`.

          It is recommended to use this overlay over directly accessing the outputs. This is because the overlay ensures that the dependencies match your system's nixpkgs version, which is most important for `mesa`. If `mesa` doesn't match, niri will be unable to run in a TTY.

          You can enable this overlay by adding this line to your configuration:

          ```nix
          {
            nixpkgs.overlays = [ niri.overlays.niri ];
          }
          ```

          You can then access the packages via `pkgs.niri-stable` and `pkgs.niri-unstable` as if they were part of nixpkgs.
        '';
      };
      b.modules = {
        a.nixos =
          module-doc "nixosModules.niri" ''
            The full NixOS module for niri.

            By default, this module does the following:

            - It will enable a binary cache managed by me, sodiboo. This helps you avoid building niri from source, which can take a long time in release mode.
            - If you have home-manager installed in your NixOS configuration (rather than as a standalone program), this module will automatically import ${link' "homeModules.config"} for all users and give it the correct package to use for validation.
            - If you have home-manager and stylix installed in your NixOS configuration, this module will also automatically import ${link' "homeModules.stylix"} for all users.
          '' {
            enable = enable-option;
            package = package-option;
            z.cache = fake-option "niri-flake.cache.enable" ''
              - type: `boolean`
              - default: `true`

              Whether or not to enable the binary cache [`niri.cachix.org`](https://niri.cachix.org/) in your nix configuration.

              Using a binary cache can save you time, by avoiding redundant rebuilds.

              This cache is managed by me, sodiboo, and i use GitHub Actions to automaticaly upload builds of ${pkg-link "niri-stable"} and ${pkg-link "niri-unstable"} (for nixpkgs unstable and stable). By using it, you are trusting me to not upload malicious builds, and as such you may disable it.

              If you do not wish to use this cache, then you may wish to set ${link' "programs.niri.package"} to ${nixpkgs-link "niri"}, in order to take advantage of the NixOS cache.
            '';
          };

        b.home =
          module-doc "homeModules.niri" ''
            The full home-manager module for niri.

            By default, this module does nothing. It will import ${link' "homeModules.config"}, which provides many configuration options, and it also provides some options to install niri.
          '' {
            enable = enable-option;
            package = package-option;
          };

        c.stylix =
          module-doc "homeModules.stylix" ''
            Stylix integration. It provides a target to enable niri.

            This module is automatically imported if you have home-manager and stylix installed in your NixOS configuration.

            If you use standalone home-manager, you must import it manually if you wish to use stylix with niri. (since it can't be automatically imported in that case)
          '' {
            target = fake-option "stylix.targets.niri.enable" ''
              - type: `boolean`
              - default: ${link-stylix-opt "stylix.autoEnable"}

              Whether to style niri according to your stylix config.

              Note that enabling this stylix target will cause a config file to be generated, even if you don't set ${link' "programs.niri.config"}.

              This also means that, with stylix installed, having everything set to default *does* generate an actual config file.
            '';
          };
      };

      z.pre-config =
        module-doc "homeModules.config" ''
          Configuration options for niri. This module is automatically imported by ${link' "nixosModules.niri"} and ${link' "homeModules.niri"}.

          By default, this module does nothing. It provides many configuration options for niri, such as keybindings, animations, and window rules.

          When its options are set, it generates `$XDG_CONFIG_HOME/niri/config.kdl` for the user. This is the default path for niri's config file.

          It will also validate the config file with the `niri validate` command before committing that config. This ensures that the config file is always valid, else your system will fail to build. When using ${link' "programs.niri.settings"} to configure niri, that's not necessary, because it will always generate a valid config file. But, if you set ${link' "programs.niri.config"} directly, then this is very useful.
        '' {
          a.variant = section ''
            ## type: `variant of`

            Some of the options below make use of a "variant" type.

            This is a type that behaves similarly to a submodule, except you can only set *one* of its suboptions.

            An example of this usage is in ${link' "programs.niri.settings.animations.<name>"}, where each event can have either an easing animation or a spring animation. \
            You cannot set parameters for both, so `variant` is used here.
          '';

          b.package = fake-option "programs.niri.package" ''
            - type: `package`
            - default: ${pkg-link "niri-stable"}

            The `niri` package that the config is validated against. This cannot be modified if you set the identically-named option in ${link' "nixosModules.niri"} or ${link' "homeModules.niri"}.
          '';
        };
    };
  };

  render = with kdl;
    cfg:
      if cfg == null
      then null
      else let
        optional-node = cond: v:
          if cond
          then v
          else null;

        nullable = f: name: value: optional-node (value != null) (f name value);
        flag' = name: flip optional-node (flag name);

        map' = node: f: name: val: node name (f val);

        toggle = disabled: cfg: contents:
          if cfg.enable
          then contents
          else flag disabled;

        pointer = cfg: [
          (flag' "natural-scroll" cfg.natural-scroll)
          (leaf "accel-speed" cfg.accel-speed)
          (nullable leaf "accel-profile" cfg.accel-profile)
        ];

        touchy = mapAttrsToList (nullable leaf);

        borderish = name: cfg:
          plain name [
            (
              toggle "off" cfg [
                (leaf "width" cfg.width)
                (leaf "active-color" cfg.active-color)
                (leaf "inactive-color" cfg.inactive-color)
                (nullable leaf "active-gradient" cfg.active-gradient)
                (nullable leaf "inactive-gradient" cfg.inactive-gradient)
              ]
            )
          ];

        preset-widths = map' plain (cfg: map (mapAttrsToList leaf) (toList cfg));

        animation = map' plain (cfg: [
          (flag' "off" (cfg == null))
          (optional-node (cfg ? easing) [
            (leaf "duration-ms" cfg.easing.duration-ms)
            (leaf "curve" cfg.easing.curve)
          ])
          (nullable leaf "spring" cfg.spring or null)
        ]);

        filter-match = map (filterAttrs (name: value: value != null));

        window-rule = cfg:
          plain "window-rule" [
            (map (leaf "matches") (filter-match cfg.matches))
            (map (leaf "excludes") (filter-match cfg.excludes))
            (nullable preset-widths "default-column-width" cfg.default-column-width)
            (nullable leaf "open-on-output" cfg.open-on-output)
            (nullable leaf "open-maximized" cfg.open-maximized)
            (nullable leaf "open-fullscreen" cfg.open-fullscreen)
          ];
        transform = cfg: let
          rotation = toString cfg.rotation;
          basic =
            if cfg.flipped
            then "flipped-${rotation}"
            else "${rotation}";
          replacement."0" = "normal";
          replacement."flipped-0" = "flipped";
        in
          replacement.${basic} or basic;

        mode = cfg: let
          cfg' = mapAttrs (const toString) cfg;
        in
          if cfg.refresh == null
          then "${cfg'.width}x${cfg'.height}"
          else "${cfg'.width}x${cfg'.height}@${cfg'.refresh}";

        normalize-bind = bind: [
          (
            if isString bind
            then flag bind
            else mapAttrsToList leaf bind
          )
        ];
      in [
        (plain "input" [
          (plain "keyboard" [
            (plain "xkb" [
              (leaf "layout" cfg.input.keyboard.xkb.layout)
              (leaf "model" cfg.input.keyboard.xkb.model)
              (leaf "rules" cfg.input.keyboard.xkb.rules)
              (leaf "variant" cfg.input.keyboard.xkb.variant)
              (nullable leaf "options" cfg.input.keyboard.xkb.options)
            ])
            (leaf "repeat-delay" cfg.input.keyboard.repeat-delay)
            (leaf "repeat-rate" cfg.input.keyboard.repeat-rate)
            (leaf "track-layout" cfg.input.keyboard.track-layout)
          ])
          (plain "touchpad" [
            (flag' "tap" cfg.input.touchpad.tap)
            (flag' "dwt" cfg.input.touchpad.dwt)
            (flag' "dwtp" cfg.input.touchpad.dwtp)
            (pointer cfg.input.touchpad)
            (nullable leaf "click-method" cfg.input.touchpad.click-method)
            (nullable leaf "tap-button-map" cfg.input.touchpad.tap-button-map)
          ])
          (plain "mouse" (pointer cfg.input.mouse))
          (plain "trackpoint" (pointer cfg.input.trackpoint))
          (plain "tablet" (touchy cfg.input.tablet))
          (plain "touch" (touchy cfg.input.touch))
          (toggle "disable-power-key-handling" cfg.input.power-key-handling [])
        ])

        (mapAttrsToList (name: cfg:
          node "output" name [
            (toggle "off" cfg [
              (leaf "scale" cfg.scale)
              (map' leaf transform "transform" cfg.transform)
              (nullable leaf "position" cfg.position)
              (nullable (map' leaf mode) "mode" cfg.mode)
            ])
          ])
        cfg.outputs)

        (leaf "screenshot-path" cfg.screenshot-path)
        (flag' "prefer-no-csd" cfg.prefer-no-csd)

        (plain "layout" [
          (leaf "gaps" cfg.layout.gaps)
          (plain "struts" [
            (leaf "left" cfg.layout.struts.left)
            (leaf "right" cfg.layout.struts.right)
            (leaf "top" cfg.layout.struts.top)
            (leaf "bottom" cfg.layout.struts.bottom)
          ])
          (borderish "focus-ring" cfg.layout.focus-ring)
          (borderish "border" cfg.layout.border)
          (preset-widths "preset-column-widths" cfg.layout.preset-column-widths)
          (preset-widths "default-column-width" cfg.layout.default-column-width)
          (leaf "center-focused-column" cfg.layout.center-focused-column)
        ])

        (plain "cursor" [
          (leaf "xcursor-theme" cfg.cursor.theme)
          (leaf "xcursor-size" cfg.cursor.size)
        ])

        (plain "hotkey-overlay" [
          (flag' "skip-at-startup" cfg.hotkey-overlay.skip-at-startup)
        ])

        (plain "environment" (mapAttrsToList leaf cfg.environment))
        (plain "binds" (mapAttrsToList (map' plain normalize-bind) cfg.binds))

        (map (map' leaf (getAttr "command") "spawn-at-startup") cfg.spawn-at-startup)
        (map window-rule cfg.window-rules)

        (plain "animations" [
          (toggle "off" cfg.animations [
            (leaf "slowdown" cfg.animations.slowdown)
            (animation "workspace-switch" cfg.animations.workspace-switch)
            (animation "horizontal-view-movement" cfg.animations.horizontal-view-movement)
            (animation "window-open" cfg.animations.window-open)
            (animation "config-notification-open-close" cfg.animations.config-notification-open-close)
          ])
        ])

        (nullable (map' plain (mapAttrsToList leaf)) "debug" cfg.debug)
      ];
}
