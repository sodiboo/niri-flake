{
  lib,
  kdl,
  fragments,
  niri-flake-internal,
  toplevel-options,
}:
let
  inherit (lib)
    types
    mkOptionType
    ;
  inherit (lib.types) enum;
  inherit (niri-flake-internal)
    fmt
    link-opt
    nullable
    float-or-int
    record
    ordered-section
    optional
    rename-warning
    ;

  libinput-anchor-for-header = lib.flip lib.pipe [
    (lib.replaceStrings (lib.upperChars ++ [ " " ]) (lib.lowerChars ++ [ "-" ]))
    (lib.splitString "")
    (lib.filter (str: lib.strings.match "[a-z0-9-]" str != null))
    lib.concatStrings
  ];
  libinput-link-href =
    page: header:
    "https://wayland.freedesktop.org/libinput/doc/latest/${page}.html#${libinput-anchor-for-header header}";
  libinput-link = page: header: fmt.bare-link (libinput-link-href page header);

  libinput-doc =
    page: header:
    fmt.masked-link {
      href = libinput-link-href page header;
      content = header;
    };

  basic-pointer = default-natural-scroll: {
    natural-scroll = optional types.bool default-natural-scroll // {
      description = ''
        Whether scrolling should move the content in the scrolled direction (as opposed to moving the viewport)

        Further reading:
        ${fmt.list [
          (libinput-link "configuration" "Scrolling")
          (libinput-link "scrolling" "Natural scrolling vs. traditional scrolling")
        ]}
      '';
    };
    middle-emulation = optional types.bool false // {
      description = ''
        Whether a middle mouse button press should be sent when you press the left and right mouse buttons

        Further reading:
        ${fmt.list [
          (libinput-link "configuration" "Middle Button Emulation")
          (libinput-link "middle-button-emulation" "Middle button emulation")
        ]}
      '';
    };
    accel-speed = nullable float-or-int // {
      description = ''
        Further reading:
        ${fmt.list [
          (libinput-link "configuration" "Pointer acceleration")
        ]}
      '';
    };
    accel-profile =
      nullable (enum [
        "adaptive"
        "flat"
      ])
      // {
        description = ''
          Further reading:
          ${fmt.list [
            (libinput-link "pointer-acceleration" "Pointer acceleration profiles")
          ]}
        '';
      };
    scroll-button = nullable types.int // {
      description =
        let
          input-event-codes-h = fmt.masked-link {
            href = "https://github.com/torvalds/linux/blob/e42b1a9a2557aa94fee47f078633677198386a52/include/uapi/linux/input-event-codes.h#L355-L363";
            content = fmt.code "input-event-codes.h";
          };
        in
        ''
          When ${fmt.code ''scroll-method = "on-button-down"''}, this is the button that will be used to enable scrolling. This button must be on the same physical device as the pointer, according to libinput docs. The type is a button code, as defined in ${input-event-codes-h}. Most commonly, this will be set to ${fmt.code "BTN_LEFT"}, ${fmt.code "BTN_MIDDLE"}, or ${fmt.code "BTN_RIGHT"}, or at least some mouse button, but any button from that file is a valid value for this option (though, libinput may not necessarily do anything useful with most of them)

          Further reading:
          ${fmt.list [
            (libinput-link "scrolling" "On-Button scrolling")
          ]}
        '';
    };
    scroll-button-lock = optional types.bool false // {
      description = ''
        When this is false, ${fmt.code "scroll-button"} needs to be held down for pointer motion to be converted to scrolling. When this is true, ${fmt.code "scroll-button"} can be pressed and released to "lock" the device into this state, until it is pressed and released a second time.

        Further reading:
        ${fmt.list [
          (libinput-link "scrolling" "On-Button scrolling")
        ]}
      '';
    };
    scroll-method =
      nullable (
        types.enum [
          "no-scroll"
          "two-finger"
          "edge"
          "on-button-down"
        ]
      )
      // {
        description = ''
          When to convert motion events to scrolling events.
          The default and supported values vary based on the device type.

          Further reading:
          ${fmt.list [
            (libinput-link "scrolling" "Scrolling")
          ]}
        '';
      };
  };

  pointer-tablet-common = {
    enable = optional types.bool true;
    left-handed = optional types.bool false // {
      description = ''
        Whether to accomodate left-handed usage for this device.
        This varies based on the exact device, but will for example swap left/right mouse buttons.

        Further reading:
        ${fmt.list [
          (libinput-link "configuration" "Left-handed Mode")
        ]}
      '';
    };
  };
in
{
  sections = [
    {
      options.input = {
        keyboard = {
          xkb =
            let
              arch-man-xkb =
                anchor:
                fmt.masked-link {
                  href = "https://man.archlinux.org/man/xkeyboard-config.7#${anchor}";
                  content = fmt.code "xkeyboard-config(7)";
                };

              default-env = default: field: ''
                If this is set to ${default}, the ${field} will be read from the ${fmt.code "XKB_DEFAULT_${lib.toUpper field}"} environment variable.
              '';

              str-fallback = default-env "an empty string";
              nullable-fallback = default-env "null";

              base = {
                layout = optional types.str "" // {
                  description = ''
                    A comma-separated list of layouts (languages) to include in the keymap.

                    See ${arch-man-xkb "LAYOUTS"} for a list of available layouts and their variants.

                    ${str-fallback "layout"}
                  '';
                };
                model = optional types.str "" // {
                  description = ''
                    The keyboard model by which to interpret keycodes and LEDs

                    See ${arch-man-xkb "MODELS"} for a list of available models.

                    ${str-fallback "model"}
                  '';
                };
                rules = optional types.str "" // {
                  description = ''
                    The rules file to use.

                    The rules file describes how to interpret the values of the model, layout, variant and options fields.

                    ${str-fallback "rules"}
                  '';
                };
                variant = optional types.str "" // {
                  description = ''
                    A comma separated list of variants, one per layout, which may modify or augment the respective layout in various ways.

                    See ${arch-man-xkb "LAYOUTS"} for a list of available variants for each layout.

                    ${str-fallback "variant"}
                  '';
                };
                options = nullable types.str // {
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
            ordered-section [
              {
                file = nullable types.str // {
                  description = ''
                    Path to a ${fmt.code ".xkb"} keymap file. If set, this file will be used to configure libxkbcommon, and all other options will be ignored.
                  '';
                };
              }
              base
            ]
            // {
              description = ''
                Parameters passed to libxkbcommon, which handles the keyboard in niri.

                Further reading:
                ${fmt.list [
                  (fmt.masked-link {
                    href = "https://docs.rs/smithay/latest/smithay/wayland/seat/struct.XkbConfig.html";
                    content = fmt.code "smithay::wayland::seat::XkbConfig";
                  })
                ]}
              '';
            };
          repeat-delay = optional types.int 600 // {
            description = ''
              The delay in milliseconds before a key starts repeating.
            '';
          };
          repeat-rate = optional types.int 25 // {
            description = ''
              The rate in characters per second at which a key repeats.
            '';
          };
          track-layout =
            optional (enum [
              "global"
              "window"
            ]) "global"
            // {
              description = ''
                The keyboard layout can be remembered per ${fmt.code ''"window"''}, such that when you switch to a window, the keyboard layout is set to the one that was last used in that window.

                By default, there is only one ${fmt.code ''"global"''} keyboard layout and changing it in any window will affect the keyboard layout used in all other windows too.
              '';
            };
          numlock = optional types.bool false // {
            description = ''
              Enable numlock by default
            '';
          };
        };
        touchpad =
          pointer-tablet-common
          // basic-pointer true
          // {
            tap = optional types.bool true // {
              description = ''
                Whether to enable tap-to-click.

                Further reading:
                ${fmt.list [
                  (libinput-link "configuration" "Tap-to-click")
                  (libinput-link "tapping" "Tap-to-click behaviour")
                ]}
              '';
            };
            dwt = optional types.bool false // {
              description = ''
                Whether to disable the touchpad while typing.

                Further reading:
                ${fmt.list [
                  (libinput-link "configuration" "Disable while typing")
                  (libinput-link "palm-detection" "Disable-while-typing")
                ]}
              '';
            };
            dwtp = optional types.bool false // {
              description = ''
                Whether to disable the touchpad while the trackpoint is in use.

                Further reading:
                ${fmt.list [
                  (libinput-link "configuration" "Disable while trackpointing")
                  (libinput-link "palm-detection" "Disable-while-trackpointing")
                ]}
              '';
            };
            drag = nullable types.bool // {
              description = ''
                On most touchpads, "tap and drag" is enabled by default. This option allows you to explicitly enable or disable it.

                Tap and drag means that to drag an item, you tap the touchpad with some amount of fingers to decide what kind of button press is emulated, but don't hold those fingers, and then you immediately start dragging with one finger.

                Further reading:
                ${fmt.list [
                  (libinput-link "tapping" "Tap-and-drag")
                ]}
              '';
            };
            drag-lock = optional types.bool false // {
              description = ''
                By default, a "tap and drag" gesture is terminated by releasing the finger that is dragging.

                Drag lock means that the drag gesture is not terminated when the finger is released, but only when the finger is tapped again, or after a timeout (unless sticky mode is enabled). This allows you to reset your finger position without losing the drag gesture.

                Drag lock is only applicable when tap and drag is enabled.

                Further reading:
                ${fmt.list [
                  (libinput-link "tapping" "Tap-and-drag")
                ]}
              '';
            };

            disabled-on-external-mouse = optional types.bool false // {
              description = ''
                Whether to disable the touchpad when an external mouse is plugged in.

                Further reading:
                ${fmt.list [
                  (libinput-link "configuration" "Send Events Mode")
                ]}
              '';
            };
            tap-button-map =
              nullable (enum [
                "left-middle-right"
                "left-right-middle"
              ])
              // {
                description = ''
                  The mouse button to register when tapping with 1, 2, or 3 fingers, when ${link-opt toplevel-options.input.touchpad.tap} is enabled.

                  Further reading:
                  ${fmt.list [
                    (libinput-link "configuration" "Tap-to-click")
                  ]}
                '';
              };
            click-method =
              nullable (enum [
                "button-areas"
                "clickfinger"
              ])
              // {
                description = ''
                  Method to determine which mouse button is pressed when you click the touchpad.

                  ${fmt.list [
                    ''
                      ${fmt.code ''"button-areas"''}: ${libinput-doc "clickpad-softbuttons" "Software button areas"} \
                      The button is determined by which part of the touchpad was clicked.
                    ''
                    ''
                      ${fmt.code ''"clickfinger"''}: ${libinput-doc "clickpad-softbuttons" "Clickfinger behavior"} \
                      The button is determined by how many fingers clicked.
                    ''
                  ]}

                  Further reading:
                  ${fmt.list [
                    (libinput-link "configuration" "Click method")
                    (libinput-link "clickpad-softbuttons" "Clickpad software button behavior")
                  ]}
                '';
              };

            scroll-factor =
              nullable (
                types.either float-or-int (record {
                  horizontal = optional float-or-int 1.0;
                  vertical = optional float-or-int 1.0;
                })
              )
              // {
                description = ''
                  For all scroll events triggered by a finger source, the scroll distance is multiplied by this factor.

                  This is not a libinput property, but rather a niri-specific one.
                '';
              };
          };
        mouse =
          pointer-tablet-common
          // basic-pointer false
          // {
            scroll-factor =
              nullable (
                types.either float-or-int (record {
                  horizontal = optional float-or-int 1.0;
                  vertical = optional float-or-int 1.0;
                })
              )
              // {
                description = ''
                  For all scroll events triggered by a wheel source, the scroll distance is multiplied by this factor.

                  This is not a libinput property, but rather a niri-specific one.
                '';
              };
          };
        trackpoint = pointer-tablet-common // basic-pointer false;
        trackball = pointer-tablet-common // basic-pointer false;
        tablet = pointer-tablet-common // {
          map-to-output = nullable types.str;
          calibration-matrix =
            nullable (mkOptionType {
              name = "matrix";
              description = "2x3 matrix";
              check =
                matrix:
                builtins.isList matrix
                && builtins.length matrix == 2
                && builtins.all (
                  row: builtins.isList row && builtins.length row == 3 && builtins.all builtins.isFloat row
                ) matrix;
              merge = lib.mergeUniqueOption {
                message = "";
                merge = loc: defs: builtins.concatLists (builtins.head defs).value;
              };
            })
            // {
              description = ''
                An augmented calibration matrix for the tablet.

                This is represented in Nix as a 2-list of 3-lists of floats.

                For example:
                ${fmt.nix-code-block ''
                  {
                    # 90 degree rotation clockwise
                    calibration-matrix = [
                      [ 0.0 -1.0 1.0 ]
                      [ 1.0  0.0 0.0 ]
                    ];
                  }
                ''}

                Further reading:
                ${fmt.list [
                  (fmt.masked-link {
                    href = "https://wayland.freedesktop.org/libinput/doc/1.8.2/group__config.html#ga3d9f1b9be10e804e170c4ea455bd1f1b";
                    content = fmt.code "libinput_device_config_calibration_get_default_matrix()";
                  })
                  (fmt.masked-link {
                    href = "https://wayland.freedesktop.org/libinput/doc/1.8.2/group__config.html#ga09a798f58cc601edd2797780096e9804";
                    content = fmt.code "libinput_device_config_calibration_set_matrix()";
                  })
                  (fmt.masked-link {
                    href = "https://smithay.github.io/smithay/input/struct.Device.html#method.config_calibration_set_matrix";
                    content = "rustdoc because libinput's web docs are an eyesore";
                  })
                ]}
              '';
            };
        };
        touch.enable = optional types.bool true;
        touch.map-to-output = nullable types.str;
        warp-mouse-to-focus =
          let
            inner = record {
              enable = optional types.bool false;
              mode = nullable types.str;
            };

            actual-type = mkOptionType {
              inherit (inner)
                name
                description
                getSubOptions
                nestedTypes
                ;

              check = value: builtins.isBool value || inner.check value;
              merge =
                loc: defs:
                lib.warnIf (builtins.any (def: builtins.isBool def.value) defs)
                  (rename-warning loc (loc ++ [ "enable" ]) (builtins.filter (def: builtins.isBool def.value) defs))
                  inner.merge
                  loc
                  (map (def: if builtins.isBool def.value then def // { value.enable = def.value; } else def) defs);
            };
          in
          optional actual-type { }
          // {
            description = ''
              Whether to warp the mouse to the focused window when switching focus.
            '';
          };
        focus-follows-mouse.enable = optional types.bool false // {
          description = ''
            Whether to focus the window under the mouse when the mouse moves.
          '';
        };
        focus-follows-mouse.max-scroll-amount = nullable types.str // {
          description = ''
            The maximum proportion of the screen to scroll at a time
          '';
        };

        workspace-auto-back-and-forth = optional types.bool false // {
          description = ''
            When invoking ${fmt.code "focus-workspace"} to switch to a workspace by index, if the workspace is already focused, usually nothing happens. When this option is enabled, the workspace will cycle back to the previously active workspace.

            Of note is that it does not switch to the previous ${fmt.em "index"}, but the previous ${fmt.em "workspace"}. That means you can reorder workspaces inbetween these actions, and it will still take you to the actual same workspace you came from.
          '';
        };

        power-key-handling.enable = optional types.bool true // {
          description = ''
            By default, niri will take over the power button to make it sleep instead of power off.

            You can disable this behaviour if you prefer to configure the power button elsewhere.
          '';
        };

        mod-key = nullable types.str;
        mod-key-nested = nullable types.str;
      };
    }
  ];
}
