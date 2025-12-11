{
  lib,
  kdl,
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
    subopts
    nullable
    float-or-int
    record
    optional
    rename-warning
    section'
    make-ordered-options
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
in
{
  sections = [
    {
      options.input =
        rendered-ordered-section
          [
            {
              options.keyboard =
                rendered-ordered-section
                  [
                    {
                      options.xkb =
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
                        in
                        lib.mkOption {
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
                          default = null;
                          type = lib.types.nullOr (
                            lib.types.submodule (
                              make-rendered-ordered-options
                                [
                                  {
                                    options.file = nullable types.str // {
                                      description = ''
                                        Path to a ${fmt.code ".xkb"} keymap file. If set, this file will be used to configure libxkbcommon, and all other options will be ignored.
                                      '';
                                    };
                                    render = config: [
                                      (lib.mkIf (config.file != null) [
                                        (kdl.leaf "file" config.file)
                                      ])
                                    ];
                                  }
                                  {
                                    options.rules = optional types.str "" // {
                                      description = ''
                                        The rules file to use.

                                        The rules file describes how to interpret the values of the model, layout, variant and options fields.

                                        ${str-fallback "rules"}
                                      '';
                                    };
                                    render = config: [
                                      (kdl.leaf "rules" config.rules)
                                    ];
                                  }
                                  {
                                    options.model = optional types.str "" // {
                                      description = ''
                                        The keyboard model by which to interpret keycodes and LEDs

                                        See ${arch-man-xkb "MODELS"} for a list of available models.

                                        ${str-fallback "model"}
                                      '';
                                    };
                                    render = config: [
                                      (kdl.leaf "model" config.model)
                                    ];
                                  }
                                  {
                                    options.layout = optional types.str "" // {
                                      description = ''
                                        A comma-separated list of layouts (languages) to include in the keymap.

                                        See ${arch-man-xkb "LAYOUTS"} for a list of available layouts and their variants.

                                        ${str-fallback "layout"}
                                      '';
                                    };
                                    render = config: [
                                      (kdl.leaf "layout" config.layout)
                                    ];
                                  }
                                  {
                                    options.variant = optional types.str "" // {
                                      description = ''
                                        A comma separated list of variants, one per layout, which may modify or augment the respective layout in various ways.

                                        See ${arch-man-xkb "LAYOUTS"} for a list of available variants for each layout.

                                        ${str-fallback "variant"}
                                      '';
                                    };
                                    render = config: [
                                      (kdl.leaf "variant" config.variant)
                                    ];
                                  }
                                  {
                                    options.options = nullable types.str // {
                                      description = ''
                                        A comma separated list of options, through which the user specifies non-layout related preferences, like which key combinations are used for switching layouts, or which key is the Compose key.

                                        See ${arch-man-xkb "OPTIONS"} for a list of available options.

                                        If this is set to an empty string, no options will be used.

                                        ${nullable-fallback "options"}
                                      '';
                                    };
                                    render = config: [
                                      (lib.mkIf (config.options != null) [
                                        (kdl.leaf "options" config.options)
                                      ])
                                    ];
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
                                    };
                                    config.rendered = kdl.plain "xkb" [ content ];
                                  }
                                )
                            )
                          );
                        };
                      render = config: [
                        (lib.mkIf (config.xkb != null) [ config.xkb.rendered ])
                      ];
                    }
                    {
                      options.repeat-delay = nullable types.int // {
                        description = ''
                          The delay in milliseconds before a key starts repeating.
                        '';
                      };
                      render = config: [
                        (lib.mkIf (config.repeat-delay != null) [
                          (kdl.leaf "repeat-delay" config.repeat-delay)
                        ])
                      ];
                    }
                    {
                      options.repeat-rate = nullable types.int // {
                        description = ''
                          The rate in characters per second at which a key repeats.
                        '';
                      };
                      render = config: [
                        (lib.mkIf (config.repeat-rate != null) [
                          (kdl.leaf "repeat-rate" config.repeat-rate)
                        ])
                      ];
                    }
                    {
                      options.track-layout =
                        nullable (enum [
                          "global"
                          "window"
                        ])
                        // {
                          description = ''
                            The keyboard layout can be remembered per ${fmt.code ''"window"''}, such that when you switch to a window, the keyboard layout is set to the one that was last used in that window.

                            By default, there is only one ${fmt.code ''"global"''} keyboard layout and changing it in any window will affect the keyboard layout used in all other windows too.
                          '';
                        };
                      render = config: [
                        (lib.mkIf (config.track-layout != null) [
                          (kdl.leaf "track-layout" config.track-layout)
                        ])
                      ];
                    }
                    {
                      options.numlock = nullable types.bool // {
                        description = ''
                          Enable numlock by default
                        '';
                      };
                      render = config: [
                        (lib.mkIf (config.numlock != null) [
                          (kdl.leaf "numlock" config.numlock)
                        ])
                      ];
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
                      config.rendered = kdl.plain "keyboard" [ content ];
                    }
                  );
              render = config: config.keyboard.rendered;
            }
            {
              options =
                let
                  pointer-like-section =
                    node: sections:
                    nullable (
                      lib.types.submodule (
                        make-rendered-ordered-options
                          (
                            [
                              {
                                options.enable = optional types.bool true;
                                render = _: [ ];
                              }
                            ]
                            ++ sections
                          )
                          (
                            content:
                            { config, ... }:
                            {
                              options.rendered = lib.mkOption {
                                type = kdl.types.kdl-node;
                                readOnly = true;
                                internal = true;
                                visible = false;
                              };
                              config.rendered = kdl.plain node [
                                (lib.mkIf (!config.enable) (kdl.flag "off"))
                                (lib.mkIf (config.enable) [ content ])
                              ];
                            }
                          )
                      )
                    );

                  chirality = [
                    {
                      options.left-handed = optional types.bool false // {
                        description = ''
                          Whether to accomodate left-handed usage for this device.
                          This varies based on the exact device, but will for example swap left/right mouse buttons.

                          Further reading:
                          ${fmt.list [
                            (libinput-link "configuration" "Left-handed Mode")
                          ]}
                        '';
                      };
                      render = config: [
                        (lib.mkIf (config.left-handed) [
                          (kdl.flag "left-handed")
                        ])
                      ];
                    }
                  ];

                  basic-pointer =
                    default-natural-scroll:
                    chirality
                    ++ [
                      {
                        options.natural-scroll = optional types.bool default-natural-scroll // {
                          description = ''
                            Whether scrolling should move the content in the scrolled direction (as opposed to moving the viewport)

                            Further reading:
                            ${fmt.list [
                              (libinput-link "configuration" "Scrolling")
                              (libinput-link "scrolling" "Natural scrolling vs. traditional scrolling")
                            ]}
                          '';
                        };
                        render = config: [
                          (lib.mkIf (config.natural-scroll) [
                            (kdl.flag "natural-scroll")
                          ])
                        ];
                      }
                      {
                        options.middle-emulation = optional types.bool false // {
                          description = ''
                            Whether a middle mouse button press should be sent when you press the left and right mouse buttons

                            Further reading:
                            ${fmt.list [
                              (libinput-link "configuration" "Middle Button Emulation")
                              (libinput-link "middle-button-emulation" "Middle button emulation")
                            ]}
                          '';
                        };

                        render = config: [
                          (lib.mkIf (config.middle-emulation) [
                            (kdl.flag "middle-emulation")
                          ])
                        ];
                      }
                      {
                        options = {
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
                        };
                        render = config: [
                          (lib.mkIf (config.accel-speed != null) [
                            (kdl.leaf "accel-speed" config.accel-speed)
                          ])
                          (lib.mkIf (config.accel-profile != null) [
                            (kdl.leaf "accel-profile" config.accel-profile)
                          ])
                        ];

                      }
                      {
                        options = {
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
                        };
                        render = config: [
                          (lib.mkIf (config.scroll-button != null) [
                            (kdl.leaf "scroll-button" config.scroll-button)
                          ])
                          (lib.mkIf (config.scroll-button-lock) [
                            (kdl.flag "scroll-button-lock")
                          ])
                        ];
                      }
                      {
                        options.scroll-method =
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
                        render = config: [
                          (lib.mkIf (config.scroll-method != null) [
                            (kdl.leaf "scroll-method" config.scroll-method)
                          ])
                        ];
                      }
                    ];

                  absolute-position = [
                    {
                      options.map-to-output = nullable types.str;
                      render = config: [
                        (lib.mkIf (config.map-to-output != null) [
                          (kdl.leaf "map-to-output" config.map-to-output)
                        ])
                      ];
                    }
                    {
                      options.calibration-matrix =
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
                            An augmented calibration matrix for the tablet or touch screen.

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
                      render = config: [
                        (lib.mkIf (config.calibration-matrix != null) [
                          (kdl.leaf "calibration-matrix" config.calibration-matrix)
                        ])
                      ];
                    }
                  ];
                in
                {
                  touchpad = pointer-like-section "touchpad" (
                    basic-pointer true
                    ++ [
                      {
                        options.tap = optional types.bool true // {
                          description = ''
                            Whether to enable tap-to-click.

                            Further reading:
                            ${fmt.list [
                              (libinput-link "configuration" "Tap-to-click")
                              (libinput-link "tapping" "Tap-to-click behaviour")
                            ]}
                          '';
                        };
                        render = config: [
                          (lib.mkIf (config.tap) [
                            (kdl.flag "tap")
                          ])
                        ];
                      }
                      {
                        options = {

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
                        };
                        render = config: [
                          (lib.mkIf (config.dwt) [
                            (kdl.flag "dwt")
                          ])
                          (lib.mkIf (config.dwtp) [
                            (kdl.flag "dwtp")
                          ])
                        ];
                      }
                      {
                        options = {
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
                        };
                        render = config: [
                          (lib.mkIf (config.drag != null) [
                            (kdl.leaf "drag" config.drag)
                          ])
                          (lib.mkIf (config.drag-lock) [
                            (kdl.flag "drag-lock")
                          ])
                        ];
                      }
                      {
                        options.disabled-on-external-mouse = optional types.bool false // {
                          description = ''
                            Whether to disable the touchpad when an external mouse is plugged in.

                            Further reading:
                            ${fmt.list [
                              (libinput-link "configuration" "Send Events Mode")
                            ]}
                          '';
                        };
                        render = config: [
                          (lib.mkIf (config.disabled-on-external-mouse) [
                            (kdl.flag "disabled-on-external-mouse")
                          ])
                        ];
                      }
                      {
                        options.tap-button-map =
                          nullable (enum [
                            "left-middle-right"
                            "left-right-middle"
                          ])
                          // {
                            description = ''
                              The mouse button to register when tapping with 1, 2, or 3 fingers, when ${link-opt (subopts (subopts toplevel-options.input).touchpad).tap} is enabled.

                              Further reading:
                              ${fmt.list [
                                (libinput-link "configuration" "Tap-to-click")
                              ]}
                            '';
                          };
                        render = config: [
                          (lib.mkIf (config.tap-button-map != null) [
                            (kdl.leaf "tap-button-map" config.tap-button-map)
                          ])
                        ];
                      }
                      {
                        options.click-method =
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
                        render = config: [
                          (lib.mkIf (config.click-method != null) [
                            (kdl.leaf "click-method" config.click-method)
                          ])
                        ];
                      }
                      {
                        options.scroll-factor =
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
                        render = config: [
                          (lib.mkIf (config.scroll-factor != null) [
                            (kdl.leaf "scroll-factor" config.scroll-factor)
                          ])
                        ];
                      }
                    ]
                  );
                  mouse = pointer-like-section "mouse" (
                    basic-pointer false
                    ++ [
                      {
                        options.scroll-factor =
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
                        render = config: [
                          (lib.mkIf (config.scroll-factor != null) [
                            (kdl.leaf "scroll-factor" config.scroll-factor)
                          ])
                        ];
                      }
                    ]
                  );
                  trackpoint = pointer-like-section "trackpoint" (basic-pointer false);
                  trackball = pointer-like-section "trackball" (basic-pointer false);
                  tablet = pointer-like-section "tablet" (chirality ++ absolute-position);
                  touch = pointer-like-section "touch" (absolute-position);
                };
              render = config: [
                (lib.mkIf (config.touchpad != null) [ config.touchpad.rendered ])
                (lib.mkIf (config.mouse != null) [ config.mouse.rendered ])
                (lib.mkIf (config.trackpoint != null) [ config.trackpoint.rendered ])
                (lib.mkIf (config.trackball != null) [ config.trackball.rendered ])
                (lib.mkIf (config.tablet != null) [ config.tablet.rendered ])
                (lib.mkIf (config.touch != null) [ config.touch.rendered ])
              ];
            }
            {
              options.warp-mouse-to-focus = lib.mkOption {
                description = ''
                  Warp the mouse to the focused window when switching focus.

                  Note that there is no way to set ${fmt.code ''enable = false;''}. If any config file enables this, it cannot be disabled by a later file.
                '';
                default = null;
                type = lib.types.nullOr (record {
                  enable = lib.mkOption {
                    default = true;
                    type = lib.types.enum [ true ];
                  };
                  mode = lib.mkOption {
                    default = null;
                    type = lib.types.nullOr (
                      lib.types.enum [
                        "center-xy"
                        "center-xy-always"
                      ]
                    );
                    description = ''
                      By default, when ${fmt.code ''mode = null;''}, if the mouse is outside of the focused window on the X axis, it will warp to the middle vertical line of the window. Likewise if it is outside the focused window on the Y axis, it will warp to the middle horizontal line. And, if it is outside the window's bounds on both axes, it will warp to the center of the window.

                      When ${fmt.code ''mode = "center-xy";''}, if the mouse is outside the window ${fmt.em "at all"}, it will warp on both axes to the very center of the window.

                      When ${fmt.code ''mode = "center-xy-always";''}, the mouse will always warp to the center of the focused window upon any focus change, even if the mouse was ${fmt.em "already"} inside the bounds of that window
                    '';
                  };
                });
              };
              render = config: [
                (lib.mkIf (config.warp-mouse-to-focus != null) [
                  (kdl.leaf "warp-mouse-to-focus" (
                    lib.optionalAttrs (config.warp-mouse-to-focus.mode != null) {
                      inherit (config.warp-mouse-to-focus) mode;
                    }
                  ))
                ])
              ];
            }
            {
              options.focus-follows-mouse = lib.mkOption {
                description = ''
                  Focus the window under the mouse when the mouse moves.

                  Note that there is no way to set ${fmt.code ''enable = false;''}. If any config file enables this, it cannot be disabled by a later file.
                '';

                default = null;
                type = lib.types.nullOr (record {
                  enable = lib.mkOption {
                    default = true;
                    type = lib.types.enum [ true ];
                  };
                  max-scroll-amount = lib.mkOption {
                    default = null;
                    type = lib.types.nullOr types.str;
                    description = ''
                      The maximum proportion of the screen to scroll at a time (expressed in percent)
                    '';
                  };
                });
              };
              render = config: [
                (lib.mkIf (config.focus-follows-mouse != null) [
                  (kdl.leaf "focus-follows-mouse" (
                    lib.optionalAttrs (config.focus-follows-mouse.max-scroll-amount != null) {
                      inherit (config.focus-follows-mouse) max-scroll-amount;
                    }
                  ))
                ])
              ];
            }
            {
              options.workspace-auto-back-and-forth = nullable types.bool // {
                description = ''
                  When invoking ${fmt.code "focus-workspace"} to switch to a workspace by index, if the workspace is already focused, usually nothing happens. When this option is enabled, the workspace will cycle back to the previously active workspace.

                  Of note is that it does not switch to the previous ${fmt.em "index"}, but the previous ${fmt.em "workspace"}. That means you can reorder workspaces inbetween these actions, and it will still take you to the actual same workspace you came from.
                '';
              };
              render = config: [
                (lib.mkIf (config.workspace-auto-back-and-forth != null) [
                  (kdl.leaf "workspace-auto-back-and-forth" config.workspace-auto-back-and-forth)
                ])
              ];
            }
            {
              options.power-key-handling.enable = nullable types.bool // {
                description = ''
                  By default, niri will take over the power button to make it sleep instead of power off.

                  You can disable this behaviour if you prefer to configure the power button elsewhere.
                '';
              };
              render = config: [
                (lib.mkIf (config.power-key-handling.enable != null) [
                  (kdl.leaf "disable-power-key-handling" (!config.power-key-handling.enable))
                ])
              ];
            }
            {
              options = {
                mod-key = nullable types.str;
                mod-key-nested = nullable types.str;
              };
              render = config: [
                (lib.mkIf (config.mod-key != null) [
                  (kdl.leaf "mod-key" config.mod-key)
                ])
                (lib.mkIf (config.mod-key-nested != null) [
                  (kdl.leaf "mod-key-nested" config.mod-key-nested)
                ])
              ];
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
              config.rendered = kdl.plain "input" [ content ];
            }
          );
      render = config: config.input.rendered;
    }
  ];
}
