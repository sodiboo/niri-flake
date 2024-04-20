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
    inherit (types) nullOr attrsOf listOf submodule enum;

    binds-stable = binds inputs.niri-stable;
    binds-unstable = binds inputs.niri-unstable;

    record = opts: let
      base = submodule (
        if builtins.isFunction opts || (opts ? options && opts ? config)
        then opts
        else {options = opts;}
      );
    in
      mkOptionType {
        name = "record";
        inherit (base) description check merge nestedTypes getSubOptions;
      };

    required = type: mkOption {inherit type;};
    nullable = type: optional (nullOr type) null;
    optional = type: default: mkOption {inherit type default;};
    readonly = type: value: optional type value // {readOnly = true;};

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

    link-type = name:
      mkOptionType {
        name = "shorthand";
        description = name;
        descriptionClass = "noun";
      };
    plain-type = description:
      mkOptionType
      {
        name = "plain";
        inherit description;
        descriptionClass = "noun";
      };
    newtype = display: inner:
      mkOptionType {
        name = "newtype";
        inherit (display) description descriptionClass;
        inherit (inner) check merge getSubOptions;
        nestedTypes = {inherit display inner;};
      };

    # niri seems to have deprecated this way of defining colors; so we won't support it
    # color-array = mkOptionType {
    #   name = "color";
    #   description = "[red green blue alpha]";
    #   descriptionClass = "noun";
    #   check = v: isList v && length v == 4 && all isInt v;
    # };

    gradient = path:
      newtype (plain-type "gradient") (record {
        from =
          required types.str
          // {
            description = ''
              The starting [`<color>`](https://developer.mozilla.org/en-US/docs/Web/CSS/color_value) of the gradient.

              For more details, see ${link' "${path}.color"}.
            '';
          };
        to =
          required types.str
          // {
            description = ''
              The ending [`<color>`](https://developer.mozilla.org/en-US/docs/Web/CSS/color_value) of the gradient.

              For more details, see ${link' "${path}.color"}.
            '';
          };
        angle =
          optional types.int 180
          // {
            description = ''
              The angle of the gradient, in degrees, measured clockwise from a gradient that starts at the bottom and ends at the top.

              This is the same as the angle parameter in the CSS [`linear-gradient()`](https://developer.mozilla.org/en-US/docs/Web/CSS/gradient/linear-gradient) function, except you can only express it in degrees.
            '';
          };
        relative-to =
          optional (enum ["window" "workspace-view"]) "window"
          // {
            description = ''
              The rectangle that this gradient is contained within.

              If a gradient is `relative-to` the `"window"`, then the gradient will start and stop at the window bounds. If you have many windows, then the gradients will have many starts and stops.

              ![
              four windows arranged in two columns; a big window to the left of three stacked windows.
              a gradient is drawn from the bottom left corner of each window, which is yellow, transitioning to red at the top right corner of each window.
              the three vertical windows look identical, with a yellow and red corner, and the other two corners are slightly different shades of orange.
              the big window has a yellow and red corner, with the top left corner being a very red orange orange, and the bottom right corner being a very yellow orange.
              the top edge of the top stacked window has a noticeable transition from a yellowish orange to completely red.
              ](assets/relative-to-window.png 'behaviour of relative-to="window"')

              If the gradient is instead `relative-to` the `"workspace-view"`, then the gradient will start and stop at the bounds of your view. Windows decorations will take on the color values from just the part of the screen that they occupy

              ![
              four windows arranged in two columns; a big window to the left of three stacked windows.
              a gradient is drawn from the bottom left corner of the workspace view, which is yellow, transitioning to red at the top right corner of the workspace view.
              it looks like the gradient starts in the bottom left of the big window, and ends in the top right of the upper stacked window.
              the bottom left corner of the top stacked window is a red orange color, and the bottom left corner of the middle stacked window is a more neutral orange color.
              the bottom edge of the big window is almost entirely yellow, and the top edge of the top stacked window is almost entirely red.
              ](/assets/relative-to-workspace-view.png 'behaviour of relative-to="workspace-view"')

              these beautiful images are sourced from the release notes for ${link-niri-release "0.1.3"}
            '';
          };
      });

    decoration = path:
      variant {
        color =
          types.str
          // {
            variant-description = ''
              A solid color to use for the decoration.

              This is a CSS [`<color>`](https://developer.mozilla.org/en-US/docs/Web/CSS/color_value) value, like `"rgb(255 0 0)"`, `"#C0FFEE"`, or `"sandybrown"`.

              The specific crate that niri uses to parse this also supports some nonstandard color functions, like `hwba()`, `hsv()`, `hsva()`. See [`csscolorparser`](https://crates.io/crates/csscolorparser) for details.
            '';
          };
        gradient =
          (gradient path)
          // {
            variant-description = ''
              A linear gradient to use for the decoration.

              This is meant to approximate the CSS [`linear-gradient()`](https://developer.mozilla.org/en-US/docs/Web/CSS/gradient/linear-gradient) function, but niri does not fully support all the same parameters. Only an angle in degrees is supported.
            '';
          };
      };

    borderish = {
      enable-by-default,
      default-active-color,
      path,
      name,
      window,
      description,
    }:
      ordered-section [
        {
          enable =
            optional types.bool enable-by-default
            // {
              description = ''
                Whether to enable the ${name}.
              '';
            };
          width =
            optional types.int 4
            // {
              description = ''
                The width of the ${name} drawn around each ${window}.
              '';
            };
        }

        {
          active =
            optional (newtype (link-type "decoration") (decoration "${path}.active")) {color = default-active-color;}
            // {
              visible = "shallow";
              description = ''
                The color of the ${name} for the window that has keyboard focus.
              '';
            };
          inactive =
            optional (newtype (link-type "decoration") (decoration "${path}.inactive")) {color = "rgb(80 80 80)";}
            // {
              visible = "shallow";
              description = ''
                The color of the ${name} for windows that do not have keyboard focus.
              '';
            };
        }
        {
          active-color =
            nullable types.str
            // {
              visible = false;
            };
          inactive-color =
            nullable types.str
            // {
              visible = false;
            };
          active-gradient =
            nullable (gradient path)
            // {
              visible = false;
            };
          inactive-gradient =
            nullable (gradient path)
            // {
              visible = false;
            };
        }
        {
          __config = cfg:
            mkMerge (concatMap (state: let
              color = "${state}-color";
              gradient = "${state}-gradient";
            in [
              (mkIf (cfg.${gradient} != null) {
                ${state}.gradient = cfg.${gradient};
              })
              (mkIf (cfg.${color} != null && cfg.${gradient} == null) {
                ${state}.color = cfg.${color};
              })
            ]) ["active" "inactive"]);
        }
      ]
      // {
        inherit description;
      };

    regex = newtype (plain-type "regular expression") types.str;

    match = newtype (plain-type "match rule") (ordered-record [
      {
        app-id =
          nullable regex
          // {
            description = ''
              A regular expression to match against the app id of the window.

              When non-null, for this field to match a window, a client must set the app id of its window and the app id must match this regex.
            '';
          };
        title =
          nullable regex
          // {
            description = ''
              A regular expression to match against the title of the window.

              When non-null, for this field to match a window, a client must set the title of its window and the title must match this regex.
            '';
          };
      }
      {
        is-active =
          nullable types.bool
          // {
            description = ''
              When non-null, for this field to match a window, the value must match whether the window is active or not.

              Every monitor has up to one active window, and `is-active=true` will match the active window on each monitor. A monitor can have zero active windows if no windows are open on it. There can never be more than one active window on a monitor.
            '';
          };
        is-focused =
          nullable types.bool
          // {
            description = ''
              When non-null, for this field to match a window, the value must match whether the window has keyboard focus or not.

              A note on terminology used here: a window is actually a toplevel surface, and a surface just refers to any rectangular region that a client can draw to. A toplevel surface is just a surface with additional capabilities and properties (e.g. "fullscreen", "resizable", "min size", etc)

              For a window to be focused, its surface must be focused. There is up to one focused surface, and it is the surface that can receive keyboard input. There can never be more than one focused surface. There can be zero focused surfaces if and only if there are zero surfaces. The focused surface does *not* have to be a toplevel surface. It can also be a layer-shell surface. In that case, there is a surface with keyboard focus but no *window* with keyboard focus.
            '';
          };
      }
    ]);

    alphabetize = sections:
      mergeAttrsList (imap0 (i: section: {
          ${elemAt strings.lowerChars i} = section;
        })
        sections);

    ordered-record = sections: let
      grouped = groupBy (s:
        if s ? __module
        then "module"
        else if s ? __config
        then "config"
        else "options")
      sections;

      options' = grouped.options or [];
      config' = map (getAttr "__config") grouped.config or [];
      module' = map (getAttr "__module") grouped.module or [];

      normalize = map (flip removeAttrs ["__docs-only"]);
      real-sections-flat = pipe options' [
        (filter (s: !(s.__docs-only or false)))
        normalize
        mergeAttrsList
      ];
      ord-sections = pipe options' [
        normalize
        alphabetize
      ];
    in
      mkOptionType {
        inherit
          (record (
            {config, ...}: {
              imports = module';
              options = real-sections-flat;
              config = mkMerge (map (f:
                f config)
              config');
            }
          ))
          name
          description
          check
          merge
          nestedTypes
          ;
        getSubOptions = loc: mapAttrs (section: opts: (record opts).getSubOptions loc) ord-sections;
      };

    make-section = flip optional {};

    section = flip pipe [record make-section];
    ordered-section = flip pipe [ordered-record make-section];

    settings = ordered-record [
      {
        binds = let
          base = record {
            allow-when-locked =
              optional types.bool false
              // {
                description = ''
                  ${unstable-note}

                  Whether this keybind should be allowed when the screen is locked.

                  This is only applicable for `spawn` keybinds.
                '';
              };
            cooldown-ms =
              nullable types.int
              // {
                description = ''
                  The minimum cooldown before a keybind can be triggered again, in milliseconds.

                  This is mostly useful for binds on the mouse wheel, where you might not want to activate an action several times in quick succession. You can use it for any bind, though.
                '';
              };
            action =
              required (newtype (plain-type "niri action") (kdl.types.kdl-leaf))
              // {
                description = ''
                  An action is represented as an attrset with a single key, being the name, and a value that is a list of its arguments. For example, to represent a spawn action, you could do this:

                  ```nix
                  {
                    programs.niri.settings.binds = {
                      "XF86AudioRaiseVolume".action.spawn = ["wpctl" "set-volume" "@DEFAULT_AUDIO_SINK@" "0.1+"];
                      "XF86AudioLowerVolume".action.spawn = ["wpctl" "set-volume" "@DEFAULT_AUDIO_SINK@" "0.1-"];
                    };
                  }
                  ```

                  If there is only a single argument, you can pass it directly. It will be implicitly converted to a list in that case.

                  ```nix
                  {
                    programs.niri.settings.binds = {
                      "Mod+D".action.spawn = "fuzzel";
                      "Mod+1".action.focus-workspace = 1;
                    };
                  }
                  ```

                  For actions taking properties (named arguments), you can pass an attrset.

                  ```nix
                  {
                    programs.niri.settings.binds = {
                      "Mod+Shift+E".action.quit.skip-confirmation = true;
                    };
                  }
                  ```

                  There is also a set of functions available under `config.lib.niri.actions`.

                  Usage is like so:

                  ```nix
                  {
                    programs.niri.settings.binds = with config.lib.niri.actions; {
                      "XF86AudioRaiseVolume".action = spawn "wpctl" "set-volume" "@DEFAULT_AUDIO_SINK@" "0.1+";
                      "XF86AudioLowerVolume".action = spawn "wpctl" "set-volume" "@DEFAULT_AUDIO_SINK@" "0.1-";

                      "Mod+D".action = spawn "fuzzel";
                      "Mod+1".action = focus-workspace 1;

                      "Mod+Shift+E".action = quit;
                      "Mod+Ctrl+Shift+E".action = quit { skip-confirmation=true; };

                      "Mod+Plus".action = set-column-width "+10%";
                    }
                  }
                  ```

                  Keep in mind that each one of these attributes (i.e. the nix bindings) are actually identical functions with different node names, and they can take arbitrarily many arguments. The documentation here is based on the *real* acceptable arguments for these actions, but the nix bindings do not enforce this. If you pass the wrong arguments, niri will reject the config file, but evaluation will proceed without problems.

                  For actions that don't take any arguments, just use the corresponding attribute from `config.lib.niri.actions`. They are listed as `action-name`. For actions that *do* take arguments, they are notated like so: `λ action-name :: <args>`, to clarify that they "should" be used as functions. Hopefully, `<args>` will be clear enough in most cases, but it's worth noting some nontrivial kinds of arguments:

                  - `size-change`: This is a special argument type used for some actions by niri. It's a string. \
                    It can take either a fixed size as an integer number of logical pixels (`"480"`, `"1200"`) or a proportion of your screen as a percentage (`"30%"`, `"70%"`) \
                    Additionally, it can either be an absolute change (setting the new size of the window), or a relative change (adding or subtracting from its size). \
                    Relative size changes are written with a `+`/`-` prefix, and absolute size changes have no prefix.

                  - `{ field :: type }`: This means that the action takes a named argument (in kdl, we call it a property). \
                    To pass such an argument, you should pass an attrset with the key and value. You can pass many properties in one attrset, or you can pass several attrsets with different properties. \
                    Required fields are marked with `*` before their name, and if no fields are required, you can use the action without any arguments too (see `quit` in the example above).

                  - `[type]`: This means that the action takes several arguments as a list. Although you can pass a list directly, it's more common to pass them as separate arguments. \
                    `spawn ["foo" "bar" "baz"]` is equivalent to `spawn "foo" "bar" "baz"`.

                  > [!tip]
                  > You can use partial application to create a spawn command with full support for shell syntax:
                  > ```nix
                  > {
                  >   programs.niri.settings.binds = with config.lib.niri.actions; let
                  >     sh = spawn "sh" "-c";
                  >   in {
                  >     "Print".action = sh '''grim -g "$(slurp)" - | wl-copy''';
                  >   };
                  > }
                  > ```

                  ${let
                    show-bind = {
                      name,
                      params,
                      ...
                    }: let
                      is-stable = any (a: a.name == name) binds-stable;
                      is-unstable = any (a: a.name == name) binds-unstable;
                      exclusive =
                        if is-stable && is-unstable
                        then ""
                        else if is-stable
                        then " (only on niri-stable)"
                        else " (only on niri-unstable)";
                      type-names = {
                        LayoutSwitchTarget = ''"next" | "prev"'';
                        SizeChange = "size-change";
                        bool = "bool";
                        u8 = "u8";
                        String = "string";
                      };

                      type-or = rust-name: fallback: type-names.${rust-name} or (warn "unhandled type `${rust-name}`" fallback);

                      base = content: "- `${content}`${exclusive}";
                      lambda = args: base "λ ${name} :: ${args}";
                    in
                      {
                        empty = base "${name}";
                        arg = lambda (type-or params.type (
                          if params.as-str
                          then "string"
                          else params.type
                        ));
                        list = lambda "[${type-or params.type params.type}]";
                        prop = lambda "{ ${optionalString (!params.use-default) "*"}${params.field} :: ${type-names.${params.type} or (warn "unhandled type `${params.type}`" params.type)} }";
                        unknown = ''
                          ${lambda "unknown"}

                            The code that generates this documentation does not know how to parse the definition:
                            ```rs
                            ${params.raw-name}(${params.raw})
                            ```
                        '';
                      }
                      .${params.kind}
                      or (abort "action `${name}` with unhandled kind `${params.kind}` for settings docs");
                  in
                    concatStringsSep "\n" (concatLists [
                      (map show-bind (filter (stable: all (unstable: stable.name != unstable.name) binds-unstable) binds-stable))
                      (map show-bind binds-unstable)
                    ])}
                '';
              };
          };

          bind = mkOptionType {
            inherit (base) name getSubOptions nestedTypes;
            description = "niri keybind";
            descriptionClass = "noun";
            check = v: isString v || isAttrs v || base.check v;
            merge = loc: defs:
              base.merge loc (map (def:
                def
                // {
                  value =
                    if def.value ? action
                    then def.value
                    else
                      warn ''

                        Deprecated definition of binds used for ${showOption loc}

                        New properties in niri require a new schema.

                        Replace binds like `programs.niri.settings.binds."Mod+T".spawn = "alacritty";` with `programs.niri.settings.binds."Mod+T".action.spawn = "alacritty";`.

                        String actions will also not be supported anymore.

                        Replace binds like `programs.niri.settings."Mod+Q" = "close-window";` with `programs.niri.settings.binds."Mod+Q".action.close-window = [];`.

                        This is not an error, and your configuration will still work, but this will not continue to be the case in the future.

                        Please see the documentation on GitHub for more information: ${link-this-github "docs.md#${anchor' "programs.niri.settings.binds"}"}
                      ''
                      (
                        if isString def.value
                        then {action.${def.value} = [];}
                        else {action = def.value;}
                      );
                })
              defs);
          };
        in
          attrs bind;
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
                layout =
                  optional types.str ""
                  // {
                    description = ''
                      A comma-separated list of layouts (languages) to include in the keymap.

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
          warp-mouse-to-focus =
            optional types.bool false
            // {
              description = ''
                Whether to warp the mouse to the focused window when switching focus.
              '';
            };
          focus-follows-mouse =
            optional types.bool false
            // {
              description = ''
                Whether to focus the window under the mouse when the mouse moves.
              '';
            };

          workspace-auto-back-and-forth =
            optional types.bool false
            // {
              description = ''
                When invoking `focus-workspace` to switch to a workspace by index, if the workspace is already focused, usually nothing happens. When this option is enabled, the workspace will cycle back to the previously active workspace.

                Of note is that it does not switch to the previous *index*, but the previous *workspace*. That means you can reorder workspaces inbetween these actions, and it will still take you to the actual same workspace you came from.
              '';
            };

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

          variable-refresh-rate =
            optional types.bool false
            // {
              description = ''
                ${unstable-note}

                Whether to enable variable refresh rate (VRR) on this output.

                VRR is also known as Adaptive Sync, FreeSync, and G-Sync.
              '';
            };
        });
      }

      {
        cursor = {
          theme =
            optional types.str "default"
            // {
              description = ''
                The name of the xcursor theme to use.

                This will also set the XCURSOR_THEME environment variable for all spawned processes.
              '';
            };
          size =
            optional types.int 24
            // {
              description = ''
                The size of the cursor in logical pixels.

                This will also set the XCURSOR_SIZE environment variable for all spawned processes.
              '';
            };
        };
      }

      {
        layout = ordered-section [
          {
            focus-ring = borderish {
              enable-by-default = true;
              default-active-color = "rgb(127 200 255)";
              path = "programs.niri.settings.layout.focus-ring";
              name = "focus ring";
              window = "focused window";
              description = ''
                The focus ring is a decoration drawn *around* the last focused window on each monitor. It takes no space away from windows. If you have insufficient gaps, the focus ring can be drawn over adjacent windows, but it will never affect the layout of windows.

                The focused window of the currently focused monitor, i.e. the window that can receive keyboard input, will be drawn according to ${link' "programs.niri.settings.layout.focus-ring.active"}, and the last focused window on all other monitors will be drawn according to ${link' "programs.niri.settings.layout.focus-ring.inactive"}.

                If you have ${link' "programs.niri.settings.layout.border"} enabled, the focus ring will be drawn around (and under) the border.
              '';
            };

            border = borderish {
              enable-by-default = false;
              default-active-color = "rgb(255 200 127)";
              path = "programs.niri.settings.layout.border";
              name = "border";
              window = "window";
              description = ''
                The border is a decoration drawn *inside* every window in the layout. It will take space away from windows. That is, if you have a border of 8px, then each window will be 8px smaller on each edge than if you had no border.

                The currently focused window, i.e. the window that can receive keyboard input, will be drawn according to ${link' "programs.niri.settings.layout.border.active"}, and all other windows will be drawn according to ${link' "programs.niri.settings.layout.border.inactive"}.

                If you have ${link' "programs.niri.settings.layout.focus-ring"} enabled, the border will be drawn inside (and over) the focus ring.
              '';
            };
          }
          {
            __docs-only = true;
            decoration =
              required (decoration "<decoration>")
              // {
                override-loc = const ["<decoration>"];
                description = ''
                  A decoration is drawn around a surface, adding additional elements that are not necessarily part of an application, but are part of what we think of as a "window".

                  This type specifically represents decorations drawn by niri: that is, ${link' "programs.niri.settings.layout.focus-ring"} and/or ${link' "programs.niri.settings.layout.border"}.


                '';
              };
          }
          {
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
          }
        ];
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
              curve =
                required (enum ["ease-out-quad" "ease-out-cubic" "ease-out-expo"])
                // {
                  description = ''
                    ${unstable-enum ["ease-out-quad"]}

                    The curve to use for the easing function.
                  '';
                };
            };
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
            window-movement.unstable = true;
            window-movement.spring = {
              damping-ratio = 1.0;
              stiffness = 800;
              epsilon = 0.0001;
            };
            window-open.easing = {
              duration-ms = 150;
              curve = "ease-out-expo";
            };
            window-close.unstable = true;
            window-close.easing = {
              duration-ms = 150;
              curve = "ease-out-quad";
            };
            window-resize.unstable = true;
            window-resize.spring = {
              damping-ratio = 1.0;
              stiffness = 800;
              epsilon = 0.0001;
            };
          };
        in
          ordered-section [
            {
              enable = optional types.bool true;
              slowdown = optional types.float 1.0;
            }
            (mapAttrs (const (v:
              optional (nullOr (newtype (link-type "animation") animation)) (removeAttrs v ["unstable"])
              // {visible = "shallow";}
              // optionalAttrs (v.unstable or false) {
                description = ''
                  ${unstable-note}
                '';
              }))
            defaults)
            {
              __module = {
                config,
                options,
                ...
              }: {
                options._internal_niri_flake =
                  readonly
                  (record (
                    concatMapAttrs (name:
                      const {
                        ${name} = readonly (record {
                          is-defined =
                            readonly types.bool (config.${name} != (removeAttrs defaults.${name} ["unstable"]));
                        }) {};
                      })
                    defaults
                  )) {}
                  // {visible = false;};
              };
            }
            {
              __docs-only = true;
              "<animation>" =
                required animation
                // {
                  override-loc = const ["<animation>"];
                };
            }
          ];
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
          list (ordered-record [
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
              {
                block-out-from =
                  nullable (enum ["screencast" "screen-capture"])
                  // {
                    description = ''
                      Whether to block out this window from screen captures. When the final value of this field is null, it is not blocked from screen captures.

                      This is useful to protect sensitive information, like the contents of password managers or private chats. It is very important to understand the implications of this option, as described below, **especially if you are a streamer or content creator**.

                      Some of this may be obvious, but in general, these invariants *should* hold true:
                      - a window is never meant to be blocked out from the actual physical screen (otherwise you wouldn't be able to see it at all)
                      - a `block-out-from` window *is* meant to be always blocked out from screencasts (as they are often used for livestreaming etc)
                      - a `block-out-from` window is *not* supposed to be blocked from screenshots (because usually these are not broadcasted live, and you generally know what you're taking a screenshot of)

                      There are three methods of screencapture in niri:

                      1. The `org.freedesktop.portal.ScreenCast` interface, which is used by tools like OBS primarily to capture video. When `block-out-from = "screencast";` or `block-out-from = "screen-capture";`, this window is blocked out from the screencast portal, and will not be visible to screencasting software making use of the screencast portal.

                      1. The `wlr-screencopy` protocol, which is used by tools like `grim` primarily to capture screenshots. When `block-out-from = "screencast";`, this protocol is not affected and tools like `grim` can still capture the window just fine. This is because you may still want to take a screenshot of such windows. However, some screenshot tools display a fullscreen overlay with a frozen image of the screen, and then capture that. This overlay is *not* blocked out in the same way, and may leak the window contents to an active screencast. When `block-out-from = "screen-capture";`, this window is blocked out from `wlr-screencopy` and thus will never leak in such a case, but of course it will always be blocked out from screenshots and (sometimes) the physical screen.

                      1. The built in `screenshot` action, implemented in niri itself. This tool works similarly to those based on `wlr-screencopy`, but being a part of the compositor gets superpowers regarding secrecy of window contents. Its frozen overlay will never leak window contents to an active screencast, because information of blocked windows and can be distinguished for the physical output and screencasts. `block-out-from` does not affect the built in screenshot tool at all, and you can always take a screenshot of any window.

                      | `block-out-from` | can `ScreenCast`? | can `screencopy`? | can `screenshot`? |
                      | --- | :---: | :---: | :---: |
                      | `null` | yes | yes | yes |
                      | `"screencast"` | no | yes | yes |
                      | `"screen-capture"` | no | no | yes |

                      > [!caution]
                      > **Streamers: Do not accidentally leak window contents via screenshots.**
                      >
                      > For windows where `block-out-from = "screencast";`, contents of a window may still be visible in a screencast, if the window is indirectly displayed by a tool using `wlr-screencopy`.
                      >
                      > If you are a streamer, either:
                      > - make sure not to use `wlr-screencopy` tools that display a preview during your stream, or
                      > - **set `block-out-from = "screen-capture";` to ensure that the window is never visible in a screencast.**

                      > [!caution]
                      > **Do not let malicious `wlr-screencopy` clients capture your top secret windows.**
                      >
                      > (and don't let malicious software run on your system in the first place, you silly goose)
                      >
                      > For windows where `block-out-from = "screencast";`, contents of a window will still be visible to any application using `wlr-screencopy`, even if you did not consent to this application capturing your screen.
                      >
                      > Note that sandboxed clients restricted via security context (i.e. Flatpaks) do not have access to `wlr-screencopy` at all, and are not a concern.
                      >
                      > **If a window's contents are so secret that they must never be captured by any (non-sandboxed) application, set `block-out-from = "screen-capture";`.**

                      Essentially, use `block-out-from = "screen-capture";` if you want to be sure that the window is never visible to any external tool no matter what; or use `block-out-from = "screencast";` if you want to be able to capture screenshots of the window without its contents normally being visible in a screencast. (at the risk of some tools still leaking the window contents, see above)
                    '';
                  };
                draw-border-with-background =
                  nullable types.bool
                  // {
                    description = ''
                      Whether to draw the focus ring and border with a background.

                      Normally, for windows with server-side decorations, niri will draw an actual border around them, because it knows they will be rectangular.

                      Because client-side decorations can take on arbitrary shapes, most notably including rounded corners, niri cannot really know the "correct" place to put a border, so for such windows it will draw a solid rectangle behind them instead.

                      For most windows, this looks okay. At worst, you have some uneven/jagged borders, instead of a gaping hole in the region outside of the corner radius of the window but inside its bounds.

                      If you wish to make windows sucha s your terminal transparent, and they use CSD, this is very undesirable. Instead of showing your wallpaper, you'll get a solid rectangle.

                      You can set this option per window to override niri's default behaviour, and instruct it to omit the border background for CSD windows. You can also explicitly enable it for SSD windows.
                    '';
                  };
                opacity =
                  nullable types.float
                  // {
                    description = ''
                      The opacity of the window, ranging from 0 to 1.

                      If the final value of this field is null, niri will fall back to a value of 1.

                      Note that this is applied in addition to the opacity set by the client. Setting this to a semitransparent value on a window that is already semitransparent will make it even more transparent.
                    '';
                  };
              }
              (let
                sizing-info = bound: ''
                  Sets the ${bound} (in logical pixels) that niri will ever ask this window for.

                  Keep in mind that the window itself always has a final say in its size, and may not respect the ${bound} set by this option.
                '';

                sizing-opt = bound:
                  nullable types.int
                  // {
                    description = sizing-info bound;
                  };
              in {
                min-width = sizing-opt "minimum width";
                max-width = sizing-opt "maximum width";
                min-height = sizing-opt "minimum height";
                max-height =
                  nullable types.int
                  // {
                    description = ''
                      ${sizing-info "maximum height"}

                      Also, note that the maximum height is not taken into account when automatically sizing columns. That is, when a column is created normally, windows in it will be "automatically sized" to fill the vertical space. This algorithm will respect a minimum height, and not make windows any smaller than that, but the max height is only taken into account if it is equal to the min height. In other words, it will only accept a "fixed height" or a "minimum height". In practice, most windows do not set a max size unless it is equal to their min size, so this is usually not a problem without window rules.

                      If you manually change the window heights, then max-height will be taken into account and restrict you from making it any taller, as you'd intuitively expect.
                    '';
                  };
              })
            ]
            // {
              description = "window rule";
              descriptionClass = "noun";
            })
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
    fmt-date,
    fmt-time,
    nixpkgs,
  }: {
    imports = [module];

    options._ = let
      pkg-output = name: desc:
        fake-option (pkg-header name) ''
          ${desc}

          To access this package under `pkgs.${name}`, you should use ${link' "overlays.niri"}.
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

      patches = pkg:
        concatMap (
          patch: let
            m = strings.match "${escapeRegex "https://github.com/YaLTeR/niri/commit/"}([0-9a-f]{40})${escapeRegex ".patch"}" patch.url;
          in
            if m != null
            then [
              {
                rev = head m;
                url = patch.url;
              }
            ]
            else []
        ) (pkg.patches or []);

      stable-patches = patches inputs.self.packages.x86_64-linux.niri-stable;
    in {
      a.nonmodules = {
        _ = header "Packages provided by this flake";

        a.packages = {
          _ = fake-option (pkg-header "<name>") ''
            (where `<system>` is one of: `x86_64-linux`, `aarch64-linux`)

            > [!important]
            > Packages for `aarch64-linux` are untested. They might work, but i can't guarantee it.

            You should preferably not be using these outputs directly. Instead, you should use ${link' "overlays.niri"}.
          '';
          niri-stable = pkg-output "niri-stable" ''
            The latest stable tagged version of niri, along with potential patches.

            Currently, this is release ${link-niri-release inputs.self.packages.x86_64-linux.niri-stable.version}${
              if stable-patches != []
              then " plus the following patches:"
              else " with no additional patches."
            }

            ${concatStringsSep "\n" (map ({
              rev,
              url,
            }: "- [`${rev}`](${removeSuffix ".patch" url})")
            stable-patches)}
          '';
          niri-unstable = pkg-output "niri-unstable" ''
            The latest commit to the development branch of niri.

            Currently, this is exactly commit ${link-niri-commit {inherit (inputs.niri-unstable) shortRev rev;}} which was authored on `${fmt-date inputs.niri-unstable.lastModifiedDate} ${fmt-time inputs.niri-unstable.lastModifiedDate}`.

            > [!warning]
            > `niri-unstable` is not a released version, there are no stability guarantees, and it may break your workflow from itme to time.
            >
            > The specific package provided by this flake is automatically updated without any testing. The only guarantee is that it builds.
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
                (nullable leaf "active-color" cfg.active.color or null)
                (nullable leaf "active-gradient" cfg.active.gradient or null)
                (nullable leaf "inactive-color" cfg.inactive.color or null)
                (nullable leaf "inactive-gradient" cfg.inactive.gradient or null)
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

        animation' = name: cfg: optional-node (cfg._internal_niri_flake.${name}.is-defined) (animation name cfg.${name});

        opt-props = filterAttrs (const (value: value != null));
        window-rule = cfg:
          plain "window-rule" [
            (map (leaf "match") (map opt-props cfg.matches))
            (map (leaf "exclude") (map opt-props cfg.excludes))
            (nullable preset-widths "default-column-width" cfg.default-column-width)
            (nullable leaf "open-on-output" cfg.open-on-output)
            (nullable leaf "open-maximized" cfg.open-maximized)
            (nullable leaf "open-fullscreen" cfg.open-fullscreen)
            (nullable leaf "draw-border-with-background" cfg.draw-border-with-background)
            (nullable leaf "opacity" cfg.opacity)
            (nullable leaf "min-width" cfg.min-width)
            (nullable leaf "max-width" cfg.max-width)
            (nullable leaf "min-height" cfg.min-height)
            (nullable leaf "max-height" cfg.max-height)
            (nullable leaf "block-out-from" cfg.block-out-from)
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

        bind = name: cfg:
          node name (opt-props {
            inherit (cfg) allow-when-locked cooldown-ms;
          }) [
            (mapAttrsToList leaf cfg.action)
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
          (flag' "warp-mouse-to-focus" cfg.input.warp-mouse-to-focus)
          (flag' "focus-follows-mouse" cfg.input.focus-follows-mouse)
          (flag' "workspace-auto-back-and-forth" cfg.input.workspace-auto-back-and-forth)
          (toggle "disable-power-key-handling" cfg.input.power-key-handling [])
        ])

        (mapAttrsToList (name: cfg:
          node "output" name [
            (toggle "off" cfg [
              (leaf "scale" cfg.scale)
              (map' leaf transform "transform" cfg.transform)
              (nullable leaf "position" cfg.position)
              (nullable (map' leaf mode) "mode" cfg.mode)
              (flag "variable-refresh-rate" cfg.variable-refresh-rate)
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
        (plain "binds" (mapAttrsToList bind cfg.binds))

        (map (map' leaf (getAttr "command") "spawn-at-startup") cfg.spawn-at-startup)
        (map window-rule cfg.window-rules)

        (plain "animations" [
          (toggle "off" cfg.animations [
            (leaf "slowdown" cfg.animations.slowdown)
            (animation' "workspace-switch" cfg.animations)
            (animation' "horizontal-view-movement" cfg.animations)
            (animation' "config-notification-open-close" cfg.animations)
            (animation' "window-movement" cfg.animations)
            (animation' "window-open" cfg.animations)
            (animation' "window-close" cfg.animations)
            (animation' "window-resize" cfg.animations)
          ])
        ])

        (nullable (map' plain (mapAttrsToList leaf)) "debug" cfg.debug)
      ];
}
