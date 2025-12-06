{
  inputs,
  kdl,
  lib,
  docs,
  binds,
  settings,
  ...
}:
{
  type-with =
    fmt:
    let
      inherit (lib)
        flip
        pipe
        showOption
        mkOption
        mkOptionType
        types
        ;
      inherit (lib.types)
        nullOr
        attrsOf
        listOf
        submodule
        enum
        ;

      binds-stable = binds "${inputs.niri-stable}/niri-config/src/binds.rs";
      binds-unstable = binds "${inputs.niri-unstable}/niri-config/src/binds.rs";

      record = record' null;

      record' =
        description: options:
        types.submoduleWith {
          inherit description;
          shorthandOnlyDefinesConfig = true;
          modules = [
            { inherit options; }
          ];
        };

      required = type: mkOption { inherit type; };
      nullable = type: optional (nullOr type) null;
      optional = type: default: mkOption { inherit type default; };
      readonly = type: value: optional type value // { readOnly = true; };
      docs-only =
        type:
        required (type // { check = _: true; })
        // {
          internal = true;
          visible = false;
          readOnly = true;
          apply = _: null;
          niri-flake-document-internal = true;
        };

      attrs = type: optional (attrsOf type) { };
      list = type: optional (listOf type) [ ];

      attrs-record = attrs-record' null;

      attrs-record' =
        description: opts:
        attrs (
          if builtins.isFunction opts then
            types.submoduleWith {
              inherit description;
              shorthandOnlyDefinesConfig = true;
              modules = [
                (
                  { name, ... }:
                  {
                    options = opts name;
                  }
                )
              ];
            }
          else
            record' description opts
        );

      float-or-int = types.either types.float types.int;

      obsolete-warning = from: to: defs: ''
        ${from} is obsolete.
        Use ${to} instead.
        ${builtins.concatStringsSep "\n" (map (def: "- defined in ${def.file}") defs)}
      '';

      rename-warning = from: to: obsolete-warning (showOption from) (showOption to);

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

      link-niri-release =
        version:
        fmt.masked-link {
          href = "https://github.com/YaLTeR/niri/releases/tag/${version}";
          content = fmt.code version;
        };

      link' =
        loc:
        fmt.masked-link {
          href = fmt.link-to-setting loc;
          content = fmt.code (lib.removePrefix "programs.niri.settings." (lib.showOption loc));
        };

      subopts =
        opt:
        assert opt._type == "option";
        opt.type.getSubOptions opt.loc;
      link-opt =
        opt:
        assert opt._type == "option";
        link' opt.loc;

      unstable-note = fmt.admonition.important ''
        This option is not yet available in stable niri.

        If you wish to modify this option, you should make sure you're using the latest unstable niri.

        Otherwise, your system might fail to build.
      '';

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

      preset-size =
        dimension: object:
        types.attrTag {
          fixed = lib.mkOption {
            type = types.int;
            description = ''
              The ${dimension} of the ${object} in logical pixels
            '';
          };
          proportion = lib.mkOption {
            type = types.float;
            description = ''
              The ${dimension} of the ${object} as a proportion of the screen's ${dimension}
            '';
          };
        };

      preset-width = preset-size "width" "column";
      preset-height = preset-size "height" "window";

      emptyOr =
        elemType:
        mkOptionType {
          name = "emptyOr";
          description =
            if
              builtins.elem elemType.descriptionClass [
                "noun"
                "conjunction"
              ]
            then
              "{} or ${elemType.description}"
            else
              "{} or (${elemType.description})";
          descriptionClass = "conjunction";
          check = v: v == { } || elemType.check v;
          nestedTypes.elemType = elemType;
          merge =
            loc: defs: if builtins.all (def: def.value == { }) defs then { } else elemType.merge loc defs;

          inherit (elemType) getSubOptions;
        };

      default-width = emptyOr preset-width;
      default-height = emptyOr preset-height;

      shorthand-for =
        type-name: real:
        mkOptionType {
          name = "shorthand";
          description = "<${type-name}>";
          descriptionClass = "noun";
          inherit (real) check merge getSubOptions;
          nestedTypes = { inherit real; };
        };

      rename =
        name: real:
        mkOptionType {
          name = "rename";
          description = "${name}";
          descriptionClass = "noun";
          inherit (real) check merge getSubOptions;
          nestedTypes = { inherit real; };
        };

      # niri seems to have deprecated this way of defining colors; so we won't support it
      # color-array = mkOptionType {
      #   name = "color";
      #   description = "[red green blue alpha]";
      #   descriptionClass = "noun";
      #   check = v: isList v && length v == 4 && all isInt v;
      # };

      decoration =
        self:

        let
          css-color = fmt.masked-link {
            href = "https://developer.mozilla.org/en-US/docs/Web/CSS/color_value";
            content = fmt.code "<color>";
          };

          css-linear-gradient = fmt.masked-link {
            href = "https://developer.mozilla.org/en-US/docs/Web/CSS/gradient/linear-gradient";
            content = fmt.code "linear-gradient()";
          };

          css-color-interpolation-method = fmt.masked-link {
            href = "https://developer.mozilla.org/en-US/docs/Web/CSS/color-interpolation-method";
            content = fmt.code "<color-interpolation-method>";
          };

          csscolorparser-crate = fmt.masked-link {
            href = "https://crates.io/crates/csscolorparser";
            content = fmt.code "csscolorparser";
          };
        in
        types.attrTag {
          color = lib.mkOption {
            type = types.str;
            description = ''
              A solid color to use for the decoration.

              This is a CSS ${css-color} value, like ${fmt.code ''"rgb(255 0 0)"''}, ${fmt.code ''"#C0FFEE"''}, or ${fmt.code ''"sandybrown"''}.

              The specific crate that niri uses to parse this also supports some nonstandard color functions, like ${fmt.code "hwba()"}, ${fmt.code "hsv()"}, ${fmt.code "hsva()"}. See ${csscolorparser-crate} for details.
            '';
          };
          gradient = lib.mkOption {
            description = ''
              A linear gradient to use for the decoration.

              This is meant to approximate the CSS ${css-linear-gradient} function, but niri does not fully support all the same parameters. Only an angle in degrees is supported.
            '';
            type = record' "gradient" {
              from = required types.str // {
                description = ''
                  The starting ${css-color} of the gradient.

                  For more details, see ${link-opt (subopts self).color}.
                '';
              };
              to = required types.str // {
                description = ''
                  The ending ${css-color} of the gradient.

                  For more details, see ${link-opt (subopts self).color}.
                '';
              };
              angle = optional types.int 180 // {
                description = ''
                  The angle of the gradient, in degrees, measured clockwise from a gradient that starts at the bottom and ends at the top.

                  This is the same as the angle parameter in the CSS ${css-linear-gradient} function, except you can only express it in degrees.
                '';
              };
              in' =
                nullable (enum [
                  "srgb"
                  "srgb-linear"
                  "oklab"
                  "oklch shorter hue"
                  "oklch longer hue"
                  "oklch increasing hue"
                  "oklch decreasing hue"
                ])
                // {
                  description = ''
                    The colorspace to interpolate the gradient in. This option is named ${fmt.code "in'"} because ${fmt.code "in"} is a reserved keyword in Nix.

                    This is a subset of the ${css-color-interpolation-method} values in CSS.
                  '';
                };
              relative-to =
                optional (enum [
                  "window"
                  "workspace-view"
                ]) "window"
                // {
                  description = ''
                    The rectangle that this gradient is contained within.

                    If a gradient is ${fmt.code "relative-to"} the ${fmt.code ''"window"''}, then the gradient will start and stop at the window bounds. If you have many windows, then the gradients will have many starts and stops.

                    ${fmt.img {
                      src = "/assets/relative-to-window.png";
                      alt = ''
                        four windows arranged in two columns; a big window to the left of three stacked windows.
                        a gradient is drawn from the bottom left corner of each window, which is yellow, transitioning to red at the top right corner of each window.
                        the three vertical windows look identical, with a yellow and red corner, and the other two corners are slightly different shades of orange.
                        the big window has a yellow and red corner, with the top left corner being a very red orange orange, and the bottom right corner being a very yellow orange.
                        the top edge of the top stacked window has a noticeable transition from a yellowish orange to completely red.
                      '';
                      title = ''behaviour of relative-to="window"'';
                    }}

                    If the gradient is instead ${fmt.code "relative-to"} the ${fmt.code ''"workspace-view"''}, then the gradient will start and stop at the bounds of your view. Windows decorations will take on the color values from just the part of the screen that they occupy

                    ${fmt.img {
                      src = "/assets/relative-to-workspace-view.png";
                      alt = ''
                        four windows arranged in two columns; a big window to the left of three stacked windows.
                        a gradient is drawn from the bottom left corner of the workspace view, which is yellow, transitioning to red at the top right corner of the workspace view.
                        it looks like the gradient starts in the bottom left of the big window, and ends in the top right of the upper stacked window.
                        the bottom left corner of the top stacked window is a red orange color, and the bottom left corner of the middle stacked window is a more neutral orange color.
                        the bottom edge of the big window is almost entirely yellow, and the top edge of the top stacked window is almost entirely red.
                      '';
                      title = ''behaviour of relative-to="workspace-view"'';
                    }}

                    these beautiful images are sourced from the release notes for ${link-niri-release "v0.1.3"}
                  '';
                };
            };
          };
        };

      make-decoration-options =
        options:
        builtins.mapAttrs (
          name:
          { description }:
          nullable (shorthand-for "decoration" (decoration (options.${name})))
          // {
            visible = "shallow";
            inherit description;
          }
        );

      borderish =
        {
          enable-by-default,
          name,
          window,
          description,
        }:
        section' (
          { options, ... }:
          {
            imports = make-ordered-options [
              {
                enable = optional types.bool enable-by-default // {
                  description = ''
                    Whether to enable the ${name}.
                  '';
                };
                width = optional float-or-int 4 // {
                  description = ''
                    The width of the ${name} drawn around each ${window}.
                  '';
                };
              }

              (make-decoration-options options {
                urgent.description = ''
                  The color of the ${name} for windows that are requesting attention.
                '';
                active.description = ''
                  The color of the ${name} for the window that has keyboard focus.
                '';
                inactive.description = ''
                  The color of the ${name} for windows that do not have keyboard focus.
                '';
              })
            ];
          }
        )
        // {
          inherit description;
        };

      border-rule =
        {
          name,
          description,
          window,
        }:
        section' (
          { options, ... }:
          {
            imports = make-ordered-options [
              {
                enable = nullable types.bool // {
                  description = ''
                    Whether to enable the ${name}.
                  '';
                };
                width = nullable float-or-int // {
                  description = ''
                    The width of the ${name} drawn around each ${window}.
                  '';
                };
              }

              (make-decoration-options options {
                urgent.description = ''
                  The color of the ${name} for windows that are requesting attention.
                '';
                active.description = ''
                  The color of the ${name} for the window that has keyboard focus.
                '';
                inactive.description = ''
                  The color of the ${name} for windows that do not have keyboard focus.
                '';
              })
            ];
          }
        )
        // {
          inherit description;
        };

      shadow-rule = section {
        enable = nullable types.bool;
        offset =
          nullable (record {
            x = required float-or-int;
            y = required float-or-int;
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

        draw-behind-window = nullable types.bool;

        color = nullable types.str;

        inactive-color = nullable types.str;
      };

      geometry-corner-radius-rule = nullable (record {
        top-left = required types.float;
        top-right = required types.float;
        bottom-right = required types.float;
        bottom-left = required types.float;
      });

      shadow-descriptions =
        let
          css-box-shadow =
            prop:
            fmt.masked-link {
              href = "https://developer.mozilla.org/en-US/docs/Web/CSS/box-shadow#syntax";
              content = "CSS box-shadow ${prop}";
            };
        in
        {
          offset = ''
            The offset of the shadow from the window, measured in logical pixels.

            This behaves like a ${css-box-shadow "offset"}
          '';

          softness = ''
            The softness/size of the shadow, measured in logical pixels.

            This behaves like a ${css-box-shadow "blur radius"}
          '';

          spread = ''
            The spread of the shadow, measured in logical pixels.

            This behaves like a ${css-box-shadow "spread radius"}
          '';
        };

      regex = rename "regular expression" types.str;

      rule-descriptions =
        {
          surface,
          surfaces,
          surface-rule,
          Surface-rules,
          example-fields,

          self,
          spawn-at-startup,
        }:

        let
          matches = link-opt (subopts self).matches;
          excludes = link-opt (subopts self).excludes;
        in
        {
          top-option = ''
            ${Surface-rules}.

            A ${surface-rule} will match based on ${matches} and ${excludes}. Both of these are lists of "match rules".

            A given match rule can match based on one of several fields. For a given match rule to "match" a ${surface}, it must match on all fields.

            ${fmt.list (
              example-fields
              ++ [
                "The ${fmt.code "at-startup"} field, when non-null, will match a ${surface} based on whether it was opened within the first 60 seconds of niri starting up."
                "If a field is null, it will always match."
              ]
            )}

            For a given ${surface-rule} to match a ${surface}, the above logic is employed to determine whether any given match rule matches, and the interactions between the match rules decide whether the ${surface-rule} as a whole will match. For a given ${surface-rule}:

            ${fmt.list [
              ''
                A given ${surface} is "considered" if any of the match rules in ${matches} successfully match this ${surface}. If all of the match rules do not match this ${surface}, then that ${surface} will never match this ${surface-rule}.
              ''
              ''
                If ${matches} contains no match rules, it will match any ${surface} and "consider" it for this ${surface-rule}.
              ''
              ''
                If a given ${surface} is "considered" for this ${surface-rule} according to the above rules, the selection can be further refined with ${excludes}. If any of the match rules in ${fmt.code "excludes"} match this ${surface}, it will be rejected and this ${surface-rule} will not match the given ${surface}.
              ''
            ]}

            That is, a given ${surface-rule} will apply to a given ${surface} if any of the entries in ${matches} match that ${surface} (or there are none), AND none of the entries in ${excludes} match that ${surface}.

            All fields of a ${surface-rule} can be set to null, which represents that the field shall have no effect on the ${surface} (and in general, the client is allowed to choose the initial value).

            To compute the final set of ${surface-rule}s that apply to a given ${surface}, each ${surface-rule} in this list is consdered in order.

            At first, every field is set to null.

            Then, for each applicable ${surface-rule}:

            ${fmt.list [
              ''
                If a given field is null on this ${surface-rule}, it has no effect. It does nothing and "inherits" the value from the previous rule.
              ''
              ''
                If the given field is not null, it will overwrite the value from any previous rule.
              ''
            ]}

            The "final value" of a field is simply its value at the end of this process. That is, the final value of a field is the one from the ${fmt.em "last"} ${surface-rule} that matches the given ${surface-rule} (not considering null entries, unless there are no non-null entries)

            If the final value of a given field is null, then it usually means that the client gets to decide. For more information, see the documentation for each field.
          '';

          match = ''
            A list of rules to match ${surfaces}.

            If any of these rules match a ${surface} (or there are none), that ${surface-rule} will be considered for this ${surface}. It can still be rejected by ${excludes}

            If all of the rules do not match a ${surface}, then this ${surface-rule} will not apply to that ${surface}.
          '';

          exclude = ''
            A list of rules to exclude ${surfaces}.

            If any of these rules match a ${surface}, then this ${surface-rule} will not apply to that ${surface}, even if it matches one of the rules in ${matches}

            If none of these rules match a ${surface}, then this ${surface-rule} will not be rejected. It will apply to that ${surface} if and only if it matches one of the rules in ${matches}
          '';

          match-at-startup = ''
            When true, this rule will match ${surfaces} opened within the first 60 seconds of niri starting up. When false, this rule will match ${surfaces} opened ${fmt.em "more than"} 60 seconds after niri started up. This is useful for applying different rules to ${surfaces} opened from ${link-opt spawn-at-startup} versus those opened later.
          '';

          opacity = ''
            The opacity of the ${surface}, ranging from 0 to 1.

            If the final value of this field is null, niri will fall back to a value of 1.

            Note that this is applied in addition to the opacity set by the client. Setting this to a semitransparent value on a ${surface} that is already semitransparent will make it even more transparent.
          '';

          block-out-from = ''
            Whether to block out this ${surface} from screen captures. When the final value of this field is null, it is not blocked out from screen captures.

            This is useful to protect sensitive information, like the contents of password managers or private chats. It is very important to understand the implications of this option, as described below, ${fmt.strong "especially if you are a streamer or content creator"}.

            Some of this may be obvious, but in general, these invariants ${fmt.em "should"} hold true:
            ${fmt.list [
              ''
                a ${surface} is never meant to be blocked out from the actual physical screen (otherwise you wouldn't be able to see it at all)
              ''
              ''
                a ${fmt.code "block-out-from"} ${surface} ${fmt.em "is"} meant to be always blocked out from screencasts (as they are often used for livestreaming etc)
              ''
              ''
                a ${fmt.code "block-out-from"} ${surface} is ${fmt.em "not"} supposed to be blocked from screenshots (because usually these are not broadcasted live, and you generally know what you're taking a screenshot of)
              ''
            ]}

            There are three methods of screencapture in niri:

            ${fmt.ordered-list [
              ''
                The ${fmt.code "org.freedesktop.portal.ScreenCast"} interface, which is used by tools like OBS primarily to capture video. When ${fmt.code ''block-out-from = "screencast";''} or ${fmt.code ''block-out-from = "screen-capture";''}, this ${surface} is blocked out from the screencast portal, and will not be visible to screencasting software making use of the screencast portal.
              ''
              ''
                The ${fmt.code "wlr-screencopy"} protocol, which is used by tools like ${fmt.code "grim"} primarily to capture screenshots. When ${fmt.code ''block-out-from = "screencast";''}, this protocol is not affected and tools like ${fmt.code "grim"} can still capture the ${surface} just fine. This is because you may still want to take a screenshot of such ${surfaces}. However, some screenshot tools display a fullscreen overlay with a frozen image of the screen, and then capture that. This overlay is ${fmt.em "not"} blocked out in the same way, and may leak the ${surface} contents to an active screencast. When ${fmt.code ''block-out-from = "screen-capture";''}, this ${surface} is blocked out from ${fmt.code "wlr-screencopy"} and thus will never leak in such a case, but of course it will always be blocked out from screenshots and (sometimes) the physical screen.
              ''
              ''
                The built in ${fmt.code "screenshot"} action, implemented in niri itself. This tool works similarly to those based on ${fmt.code "wlr-screencopy"}, but being a part of the compositor gets superpowers regarding secrecy of ${surface} contents. Its frozen overlay will never leak ${surface} contents to an active screencast, because information of blocked ${surfaces} and can be distinguished for the physical output and screencasts. ${fmt.code "block-out-from"} does not affect the built in screenshot tool at all, and you can always take a screenshot of any ${surface}.
              ''
            ]}

            ${fmt.table {
              headers = [
                (fmt.code "block-out-from")
                "can ${fmt.code "ScreenCast"}?"
                "can ${fmt.code "screencopy"}?"
                "can ${fmt.code "screenshot"}?"
              ];
              align = [
                null
                "center"
                "center"
                "center"
              ];
              rows = [
                [
                  (fmt.code "null")
                  "yes"
                  "yes"
                  "yes"
                ]
                [
                  (fmt.code ''"screencast"'')
                  "no"
                  "yes"
                  "yes"
                ]
                [
                  (fmt.code ''"screen-capture"'')
                  "no"
                  "no"
                  "yes"
                ]
              ];
            }}

            ${fmt.admonition.caution ''
              ${fmt.strong "Streamers: Do not accidentally leak ${surface} contents via screenshots."}

              For ${surfaces} where ${fmt.code ''block-out-from = "screencast";''}, contents of a ${surface} may still be visible in a screencast, if the ${surface} is indirectly displayed by a tool using ${fmt.code "wlr-screencopy"}.

              If you are a streamer, either:
              ${fmt.list [
                "make sure not to use ${fmt.code "wlr-screencopy"} tools that display a preview during your stream, or"
                (fmt.strong "set ${fmt.code ''block-out-from = "screen-capture";''} to ensure that the ${surface} is never visible in a screencast.")
              ]}
            ''}

            ${fmt.admonition.caution ''
              ${fmt.strong "Do not let malicious ${fmt.code "wlr-screencopy"} clients capture your top secret ${surfaces}."}

              (and don't let malicious software run on your system in the first place, you silly goose)

              For ${surfaces} where ${fmt.code ''block-out-from = "screencast";''}, contents of a ${surface} will still be visible to any application using ${fmt.code "wlr-screencopy"}, even if you did not consent to this application capturing your screen.

              Note that sandboxed clients restricted via security context (i.e. Flatpaks) do not have access to ${fmt.code "wlr-screencopy"} at all, and are not a concern.

              ${fmt.strong "If a ${surface}'s contents are so secret that they must never be captured by any (non-sandboxed) application, set ${fmt.code ''block-out-from = "screen-capture";''}."}
            ''}

            Essentially, use ${fmt.code ''block-out-from = "screen-capture";''} if you want to be sure that the ${surface} is never visible to any external tool no matter what; or use ${fmt.code ''block-out-from = "screencast";''} if you want to be able to capture screenshots of the ${surface} without its contents normally being visible in a screencast. (at the risk of some tools still leaking the ${surface} contents, see above)
          '';
        };

      alphabetize =
        sections:
        lib.mergeAttrsList (
          lib.imap0 (i: section: {
            ${builtins.elemAt lib.strings.lowerChars i} = section;
          }) sections
        );

      ordered-record = ordered-record' null;

      ordered-record' =
        description: sections:
        types.submoduleWith {
          inherit description;
          shorthandOnlyDefinesConfig = true;
          modules = make-ordered-options sections;
        };

      make-ordered-options =
        sections:
        let
          grouped = lib.groupBy (s: if s ? __module then "module" else "options") sections;

          options' = grouped.options or [ ];
          module' = map (builtins.getAttr "__module") grouped.module or [ ];

          flat-options = lib.mergeAttrsList options';

          real-options = lib.filterAttrs (_: opt: !(opt ? niri-flake-document-internal)) flat-options;

          extra-docs-options = lib.filterAttrs (_: opt: opt ? niri-flake-document-internal) flat-options;
        in
        module'
        ++ [
          {
            options = real-options;
          }
          {
            options._module.niri-flake-ordered-record = {
              ordering = lib.mkOption {
                internal = true;
                # readOnly = true;
                visible = false;
                description = ''
                  Used to influence the order of options in the documentation, such that they are not always sorted alphabetically.

                  Does not affect any other functionality.
                '';
                default = builtins.concatMap builtins.attrNames options';
              };

              inherit extra-docs-options;
            };
          }

        ];

      make-section = type: optional type { };

      section' = flip pipe [
        submodule
        make-section
      ];
      section = flip pipe [
        record
        make-section
      ];
      ordered-section = flip pipe [
        ordered-record
        make-section
      ];
    in
    lib.types.submoduleWith {
      modules = [ ./settings/toplevel.nix ];
      specialArgs = {
        inherit kdl;
        niri-flake-internal = {
          inherit
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
            record'
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
            rename
            shorthand-for
            ordered-section
            docs-only
            attrs-record
            attrs-record'
            optional
            pointer-tablet-common
            basic-pointer
            libinput-link
            libinput-doc
            rename-warning
            obsolete-warning
            borderish
            decoration
            preset-width
            preset-height
            ;
        };
      };
    };

  module =
    {
      config,
      pkgs,
      ...
    }:
    let
      cfg = config.programs.niri;

      inherit (lib) mkOption types;
      inherit (docs.lib) link';
    in
    {
      options.programs.niri = {
        settings = mkOption {
          type = types.nullOr (settings.type-with docs.settings-fmt);
          default = null;
          description = ''
            Nix-native settings for niri.

            By default, when this is null, no config file is generated.

            Beware that setting ${link' "programs.niri.config"} completely overrides everything under this option.
          '';
        };

        config = mkOption {
          type = types.nullOr (types.either types.str kdl.types.kdl-document);
          default = settings.render cfg.settings;
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
            if builtins.isString cfg.config then
              cfg.config
            else if cfg.config != null then
              if config._module.args ? pkgs then
                builtins.readFile (
                  pkgs.callPackage kdl.generator {
                    document = cfg.config;
                  }
                )
              else
                ''
                  invalid // mock instantiation of this module. unable to generate configuration.
                ''
            else
              null;
          readOnly = true;
          defaultText = null;
          description = ''
            The final niri config file contents.

            This is a string that reflects the document stored in ${link' "programs.niri.config"}.

            It is exposed mainly for debugging purposes, such as when you need to inspect how a certain option affects the resulting config file.
          '';
        };
      };
    };
  fake-docs =
    {
      fmt-date,
      fmt-time,
    }:
    {
      imports = [ settings.module ];

      options._ =
        let
          inherit (docs.lib)
            section
            header
            pkg-header
            module-doc
            fake-option
            pkg-link
            nixpkgs-link
            link-niri-release
            link-niri-commit
            link-stylix-opt
            link'
            ;

          pkg-output =
            name: desc:
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

          patches =
            pkg:
            builtins.concatMap (
              patch:
              let
                m = lib.strings.match "${lib.escapeRegex "https://github.com/YaLTeR/niri/commit/"}([0-9a-f]{40})${lib.escapeRegex ".patch"}" patch.url;
              in
              if m != null then
                [
                  {
                    rev = builtins.head m;
                    inherit (patch) url;
                  }
                ]
              else
                [ ]
            ) (pkg.patches or [ ]);

          stable-patches = patches inputs.self.packages.x86_64-linux.niri-stable;
        in
        {
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
                  if stable-patches != [ ] then " plus the following patches:" else " with no additional patches."
                }

                ${builtins.concatStringsSep "\n" (
                  map (
                    {
                      rev,
                      url,
                    }:
                    "- [`${rev}`](${lib.removeSuffix ".patch" url})"
                  ) stable-patches
                )}
              '';
              niri-unstable = pkg-output "niri-unstable" ''
                The latest commit to the development branch of niri.

                Currently, this is exactly commit ${
                  link-niri-commit { inherit (inputs.niri-unstable) shortRev rev; }
                } which was authored on `${fmt-date inputs.niri-unstable.lastModifiedDate} ${fmt-time inputs.niri-unstable.lastModifiedDate}`.

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
              module-doc "nixosModules.niri"
                ''
                  The full NixOS module for niri.

                  By default, this module does the following:

                  - It will enable a binary cache managed by me, sodiboo. This helps you avoid building niri from source, which can take a long time in release mode.
                  - If you have home-manager installed in your NixOS configuration (rather than as a standalone program), this module will automatically import ${link' "homeModules.config"} for all users and give it the correct package to use for validation.
                  - If you have home-manager and stylix installed in your NixOS configuration, this module will also automatically import ${link' "homeModules.stylix"} for all users.
                ''
                {
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
              module-doc "homeModules.niri"
                ''
                  The full home-manager module for niri.

                  By default, this module does nothing. It will import ${link' "homeModules.config"}, which provides many configuration options, and it also provides some options to install niri.
                ''
                {
                  enable = enable-option;
                  package = package-option;
                };

            c.stylix =
              module-doc "homeModules.stylix"
                ''
                  Stylix integration. It provides a target to enable niri.

                  This module is automatically imported if you have home-manager and stylix installed in your NixOS configuration.

                  If you use standalone home-manager, you must import it manually if you wish to use stylix with niri. (since it can't be automatically imported in that case)
                ''
                {
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
            module-doc "homeModules.config"
              ''
                Configuration options for niri. This module is automatically imported by ${link' "nixosModules.niri"} and ${link' "homeModules.niri"}.

                By default, this module does nothing. It provides many configuration options for niri, such as keybindings, animations, and window rules.

                When its options are set, it generates `$XDG_CONFIG_HOME/niri/config.kdl` for the user. This is the default path for niri's config file.

                It will also validate the config file with the `niri validate` command before committing that config. This ensures that the config file is always valid, else your system will fail to build. When using ${link' "programs.niri.settings"} to configure niri, that's not necessary, because it will always generate a valid config file. But, if you set ${link' "programs.niri.config"} directly, then this is very useful.
              ''
              {
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

  render =
    cfg:
    if cfg == null then
      null
    else
      let
        normalize-nodes = nodes: lib.remove null (lib.flatten nodes);

        node =
          name: args: children:
          kdl.node name args (normalize-nodes children);
        plain = name: node name [ ];
        leaf = name: args: node name args [ ];
        flag = name: node name [ ] [ ];

        optional-node = cond: v: if cond then v else null;

        nullable =
          f: name: value:
          optional-node (value != null) (f name value);
        flag' = name: lib.flip optional-node (flag name);
        plain' =
          name: children:
          optional-node (builtins.any (v: v != null) (lib.flatten children)) (plain name children);

        map' =
          node: f: name: val:
          node name (f val);

        each = list: f: map f list;
        each' = attrs: each (builtins.attrValues attrs);

        toggle =
          disabled: cfg: contents:
          if cfg.enable then contents else flag disabled;

        toggle' = disabled: cfg: contents: [
          (flag' disabled (cfg.enable == false))
          contents
        ];

        pointer = cfg: [
          (flag' "natural-scroll" cfg.natural-scroll)
          (flag' "middle-emulation" cfg.middle-emulation)
          (nullable leaf "accel-speed" cfg.accel-speed)
          (nullable leaf "accel-profile" cfg.accel-profile)
          (nullable leaf "scroll-button" cfg.scroll-button)
          (flag' "scroll-button-lock" cfg.scroll-button-lock)
          (nullable leaf "scroll-method" cfg.scroll-method)
        ];

        pointer-tablet =
          cfg: inner:
          (toggle "off" cfg [
            (flag' "left-handed" cfg.left-handed)
            inner
          ]);

        touchy = cfg: [
          (nullable leaf "map-to-output" cfg.map-to-output)
        ];

        tablet =
          cfg:
          touchy cfg
          ++ [
            (nullable leaf "calibration-matrix" cfg.calibration-matrix)
          ];

        touch =
          cfg:
          (toggle "off" cfg [
            (touchy cfg)
          ]);

        gradient' =
          name: cfg:
          leaf name (
            lib.concatMapAttrs (
              name: value:
              lib.optionalAttrs (value != null) {
                ${lib.removeSuffix "'" name} = value;
              }
            ) cfg
          );

        borderish = map' plain (
          cfg:
          toggle "off" cfg [
            (leaf "width" cfg.width)
            (nullable leaf "urgent-color" cfg.urgent.color or null)
            (nullable gradient' "urgent-gradient" cfg.urgent.gradient or null)
            (nullable leaf "active-color" cfg.active.color or null)
            (nullable gradient' "active-gradient" cfg.active.gradient or null)
            (nullable leaf "inactive-color" cfg.inactive.color or null)
            (nullable gradient' "inactive-gradient" cfg.inactive.gradient or null)
          ]
        );

        shadow = map' (nullable plain) (
          cfg:
          optional-node (cfg.enable) [
            (flag "on")
            (leaf "offset" cfg.offset)
            (leaf "softness" cfg.softness)
            (leaf "spread" cfg.spread)

            (leaf "draw-behind-window" cfg.draw-behind-window)
            (leaf "color" cfg.color)
            (nullable leaf "inactive-color" cfg.inactive-color)
          ]
        );

        tab-indicator = map' plain (
          cfg:
          toggle "off" cfg [
            (flag' "hide-when-single-tab" cfg.hide-when-single-tab)
            (flag' "place-within-column" cfg.place-within-column)
            (leaf "gap" cfg.gap)
            (leaf "width" cfg.width)
            (leaf "length" cfg.length)
            (leaf "position" cfg.position)
            (leaf "gaps-between-tabs" cfg.gaps-between-tabs)
            (leaf "corner-radius" cfg.corner-radius)
            (nullable leaf "urgent-color" cfg.urgent.color or null)
            (nullable gradient' "urgent-gradient" cfg.urgent.gradient or null)
            (nullable leaf "active-color" cfg.active.color or null)
            (nullable gradient' "active-gradient" cfg.active.gradient or null)
            (nullable leaf "inactive-color" cfg.inactive.color or null)
            (nullable gradient' "inactive-gradient" cfg.inactive.gradient or null)
          ]
        );

        preset-sizes = map' (nullable plain) (
          cfg: if cfg == [ ] then null else map (lib.mapAttrsToList leaf) (lib.toList cfg)
        );

        animation = map' plain' (
          cfg:
          toggle "off" cfg [
            (optional-node (cfg.kind ? easing) [
              (leaf "duration-ms" cfg.kind.easing.duration-ms)
              (leaf "curve" ([ cfg.kind.easing.curve ] ++ cfg.kind.easing.curve-args))
            ])
            (nullable leaf "spring" cfg.kind.spring or null)
            (nullable leaf "custom-shader" cfg.custom-shader or null)
          ]
        );

        opt-props = lib.filterAttrs (lib.const (value: value != null));
        border-rule = map' plain' (cfg: [
          (flag' "on" (cfg.enable == true))
          (flag' "off" (cfg.enable == false))
          (nullable leaf "width" cfg.width)
          (nullable leaf "urgent-color" cfg.urgent.color or null)
          (nullable gradient' "urgent-gradient" cfg.urgent.gradient or null)
          (nullable leaf "active-color" cfg.active.color or null)
          (nullable gradient' "active-gradient" cfg.active.gradient or null)
          (nullable leaf "inactive-color" cfg.inactive.color or null)
          (nullable gradient' "inactive-gradient" cfg.inactive.gradient or null)
        ]);

        shadow-rule = map' plain' (cfg: [
          (flag' "on" (cfg.enable == true))
          (flag' "off" (cfg.enable == false))
          (nullable leaf "offset" cfg.offset)
          (nullable leaf "softness" cfg.softness)
          (nullable leaf "spread" cfg.spread)
          (nullable leaf "draw-behind-window" cfg.draw-behind-window)
          (nullable leaf "color" cfg.color)
          (nullable leaf "inactive-color" cfg.inactive-color)
        ]);

        tab-indicator-rule = map' plain' (cfg: [
          (nullable leaf "urgent-color" cfg.urgent.color or null)
          (nullable gradient' "urgent-gradient" cfg.urgent.gradient or null)
          (nullable leaf "active-color" cfg.active.color or null)
          (nullable gradient' "active-gradient" cfg.active.gradient or null)
          (nullable leaf "inactive-color" cfg.inactive.color or null)
          (nullable gradient' "inactive-gradient" cfg.inactive.gradient or null)
        ]);

        corner-radius = cfg: [
          cfg.top-left
          cfg.top-right
          cfg.bottom-right
          cfg.bottom-left
        ];

        transform =
          cfg:
          let
            rotation = toString cfg.rotation;
            basic = if cfg.flipped then "flipped-${rotation}" else "${rotation}";
            replacement."0" = "normal";
            replacement."flipped-0" = "flipped";
          in
          replacement.${basic} or basic;

        mode =
          cfg:
          let
            cfg' = builtins.mapAttrs (lib.const toString) cfg;
          in
          if cfg.refresh == null then
            "${cfg'.width}x${cfg'.height}"
          else
            "${cfg'.width}x${cfg'.height}@${cfg'.refresh}";

        bind =
          name: cfg:
          let
            bool-props-with-defaults =
              cfg: defaults:
              opt-props (
                builtins.mapAttrs (
                  name: value: (if (defaults ? ${name}) && (value != defaults.${name}) then value else null)
                ) cfg
              );
          in
          node name
            (
              opt-props {
                inherit (cfg) cooldown-ms;
              }
              // bool-props-with-defaults cfg {
                repeat = true;
                allow-when-locked = false;
                allow-inhibiting = true;
              }
              // lib.optionalAttrs (cfg.hotkey-overlay.hidden or false) {
                hotkey-overlay-title = null;
              }
              // opt-props {
                hotkey-overlay-title = cfg.hotkey-overlay.title or null;
              }
            )
            [
              (lib.mapAttrsToList leaf cfg.action)
            ];

        pointer-tablet' =
          ext: name: cfg:
          plain' name (pointer-tablet cfg (ext cfg));
        pointer' = pointer-tablet' pointer;
        tablet' = pointer-tablet' tablet;
      in
      normalize-nodes [
        (plain "input" [
          (plain "keyboard" [
            (plain "xkb" [
              (nullable leaf "file" cfg.input.keyboard.xkb.file)
              (leaf "layout" cfg.input.keyboard.xkb.layout)
              (leaf "model" cfg.input.keyboard.xkb.model)
              (leaf "rules" cfg.input.keyboard.xkb.rules)
              (leaf "variant" cfg.input.keyboard.xkb.variant)
              (nullable leaf "options" cfg.input.keyboard.xkb.options)
            ])
            (leaf "repeat-delay" cfg.input.keyboard.repeat-delay)
            (leaf "repeat-rate" cfg.input.keyboard.repeat-rate)
            (leaf "track-layout" cfg.input.keyboard.track-layout)
            (flag' "numlock" cfg.input.keyboard.numlock)
          ])
          (plain' "touchpad" (
            pointer-tablet cfg.input.touchpad [
              (flag' "tap" cfg.input.touchpad.tap)
              (flag' "dwt" cfg.input.touchpad.dwt)
              (flag' "dwtp" cfg.input.touchpad.dwtp)
              (nullable leaf "drag" cfg.input.touchpad.drag)
              (flag' "drag-lock" cfg.input.touchpad.drag-lock)
              (flag' "disabled-on-external-mouse" cfg.input.touchpad.disabled-on-external-mouse)
              (pointer cfg.input.touchpad)
              (nullable leaf "click-method" cfg.input.touchpad.click-method)
              (nullable leaf "tap-button-map" cfg.input.touchpad.tap-button-map)
              (nullable leaf "scroll-factor" cfg.input.touchpad.scroll-factor)
            ]
          ))
          (plain' "mouse" (
            pointer-tablet cfg.input.mouse [
              (pointer cfg.input.mouse)
              (nullable leaf "scroll-factor" cfg.input.mouse.scroll-factor)
            ]
          ))
          (pointer' "trackpoint" cfg.input.trackpoint)
          (pointer' "trackball" cfg.input.trackball)
          (tablet' "tablet" cfg.input.tablet)
          (plain' "touch" (touch cfg.input.touch))
          (optional-node cfg.input.warp-mouse-to-focus.enable (
            leaf "warp-mouse-to-focus" (
              lib.optionalAttrs (cfg.input.warp-mouse-to-focus.mode != null) {
                inherit (cfg.input.warp-mouse-to-focus) mode;
              }
            )
          ))
          (optional-node cfg.input.focus-follows-mouse.enable (
            leaf "focus-follows-mouse" (
              lib.optionalAttrs (cfg.input.focus-follows-mouse.max-scroll-amount != null) {
                inherit (cfg.input.focus-follows-mouse) max-scroll-amount;
              }
            )
          ))
          (flag' "workspace-auto-back-and-forth" cfg.input.workspace-auto-back-and-forth)
          (toggle "disable-power-key-handling" cfg.input.power-key-handling [ ])
          (nullable leaf "mod-key" cfg.input.mod-key)
          (nullable leaf "mod-key-nested" cfg.input.mod-key-nested)
        ])

        (each' cfg.outputs (cfg: [
          (node "output" cfg.name [
            (toggle' "off" cfg [
              (nullable leaf "backdrop-color" cfg.backdrop-color)
              (nullable leaf "background-color" cfg.background-color)
              (nullable leaf "scale" cfg.scale)
              (flag' "focus-at-startup" cfg.focus-at-startup)
              (map' leaf transform "transform" cfg.transform)
              (nullable leaf "position" cfg.position)
              (nullable (map' leaf mode) "mode" cfg.mode)
              (optional-node (cfg.variable-refresh-rate != false) (
                leaf "variable-refresh-rate" { on-demand = cfg.variable-refresh-rate == "on-demand"; }
              ))
            ])
          ])
        ]))

        (leaf "screenshot-path" cfg.screenshot-path)
        (flag' "prefer-no-csd" cfg.prefer-no-csd)

        (plain' "overview" [
          (nullable leaf "zoom" cfg.overview.zoom)
          (nullable leaf "backdrop-color" cfg.overview.backdrop-color)
          (plain' "workspace-shadow" [
            (toggle "off" cfg.overview.workspace-shadow [
              (nullable leaf "offset" cfg.overview.workspace-shadow.offset)
              (nullable leaf "softness" cfg.overview.workspace-shadow.softness)
              (nullable leaf "spread" cfg.overview.workspace-shadow.spread)
              (nullable leaf "color" cfg.overview.workspace-shadow.color)
            ])
          ])
        ])

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
          (nullable leaf "background-color" cfg.layout.background-color)
          (shadow "shadow" cfg.layout.shadow)
          (nullable tab-indicator "tab-indicator" cfg.layout.tab-indicator)
          (plain' "insert-hint" [
            (toggle "off" cfg.layout.insert-hint [
              (nullable leaf "color" cfg.layout.insert-hint.display.color or null)
              (nullable gradient' "gradient" cfg.layout.insert-hint.display.gradient or null)
            ])
          ])
          (preset-sizes "default-column-width" cfg.layout.default-column-width)
          (preset-sizes "preset-column-widths" cfg.layout.preset-column-widths)
          (preset-sizes "preset-window-heights" cfg.layout.preset-window-heights)
          (leaf "center-focused-column" cfg.layout.center-focused-column)
          (optional-node (cfg.layout.default-column-display != "normal") (
            leaf "default-column-display" cfg.layout.default-column-display
          ))
          (flag' "always-center-single-column" cfg.layout.always-center-single-column)
          (flag' "empty-workspace-above-first" cfg.layout.empty-workspace-above-first)
        ])

        (plain "cursor" [
          (leaf "xcursor-theme" cfg.cursor.theme)
          (leaf "xcursor-size" cfg.cursor.size)
          (flag' "hide-when-typing" cfg.cursor.hide-when-typing)
          (nullable leaf "hide-after-inactive-ms" cfg.cursor.hide-after-inactive-ms)
        ])

        (plain' "hotkey-overlay" [
          (flag' "skip-at-startup" cfg.hotkey-overlay.skip-at-startup)
          (flag' "hide-not-bound" cfg.hotkey-overlay.hide-not-bound)
        ])

        (plain' "config-notification" [
          (flag' "disable-failed" cfg.config-notification.disable-failed)
        ])

        (plain' "clipboard" [
          (flag' "disable-primary" cfg.clipboard.disable-primary)
        ])

        (plain' "environment" (lib.mapAttrsToList leaf cfg.environment))
        (plain' "binds" (lib.mapAttrsToList bind cfg.binds))

        (plain' "switch-events" (
          lib.mapAttrsToList (nullable (
            map' plain (cfg: [
              (lib.mapAttrsToList leaf cfg.action)
            ])
          )) cfg.switch-events
        ))

        (each' cfg.workspaces (cfg: [
          (node "workspace" cfg.name [
            (nullable leaf "open-on-output" cfg.open-on-output)
          ])
        ]))

        (each cfg.spawn-at-startup (cfg: [
          (nullable leaf "spawn-at-startup" cfg.argv or null)
          (nullable leaf "spawn-sh-at-startup" cfg.sh or null)
          (nullable leaf "spawn-at-startup" cfg.command or null)
        ]))

        (each cfg.window-rules (cfg: [
          (plain "window-rule" [
            (map (leaf "match") (map opt-props cfg.matches))
            (map (leaf "exclude") (map opt-props cfg.excludes))
            (nullable preset-sizes "default-column-width" cfg.default-column-width)
            (nullable preset-sizes "default-window-height" cfg.default-window-height)
            (nullable leaf "default-column-display" cfg.default-column-display)
            (nullable leaf "open-on-output" cfg.open-on-output)
            (nullable leaf "open-on-workspace" cfg.open-on-workspace)
            (nullable leaf "open-maximized" cfg.open-maximized)
            (nullable leaf "open-fullscreen" cfg.open-fullscreen)
            (nullable leaf "open-floating" cfg.open-floating)
            (nullable leaf "open-focused" cfg.open-focused)
            (nullable leaf "draw-border-with-background" cfg.draw-border-with-background)
            (nullable (map' leaf corner-radius) "geometry-corner-radius" cfg.geometry-corner-radius)
            (nullable leaf "clip-to-geometry" cfg.clip-to-geometry)
            (border-rule "border" cfg.border)
            (border-rule "focus-ring" cfg.focus-ring)
            (shadow-rule "shadow" cfg.shadow)
            (tab-indicator-rule "tab-indicator" cfg.tab-indicator)
            (nullable leaf "opacity" cfg.opacity)
            (nullable leaf "min-width" cfg.min-width)
            (nullable leaf "max-width" cfg.max-width)
            (nullable leaf "min-height" cfg.min-height)
            (nullable leaf "max-height" cfg.max-height)
            (nullable leaf "block-out-from" cfg.block-out-from)
            (nullable leaf "baba-is-float" cfg.baba-is-float)
            (nullable leaf "default-floating-position" cfg.default-floating-position)
            (nullable leaf "variable-refresh-rate" cfg.variable-refresh-rate)
            (nullable leaf "scroll-factor" cfg.scroll-factor)
            (nullable leaf "tiled-state" cfg.tiled-state)
          ])
        ]))
        (each cfg.layer-rules (cfg: [
          (plain "layer-rule" [
            (map (leaf "match") (map opt-props cfg.matches))
            (map (leaf "exclude") (map opt-props cfg.excludes))
            (nullable leaf "opacity" cfg.opacity)
            (nullable leaf "block-out-from" cfg.block-out-from)
            (shadow-rule "shadow" cfg.shadow)
            (nullable (map' leaf corner-radius) "geometry-corner-radius" cfg.geometry-corner-radius)
            (nullable leaf "place-within-backdrop" cfg.place-within-backdrop)
            (nullable leaf "baba-is-float" cfg.baba-is-float)
          ])
        ]))

        (plain' "gestures" [
          (plain' "dnd-edge-view-scroll" [
            (nullable leaf "trigger-width" cfg.gestures.dnd-edge-view-scroll.trigger-width)
            (nullable leaf "delay-ms" cfg.gestures.dnd-edge-view-scroll.delay-ms)
            (nullable leaf "max-speed" cfg.gestures.dnd-edge-view-scroll.max-speed)
          ])
          (plain' "dnd-edge-workspace-switch" [
            (nullable leaf "trigger-height" cfg.gestures.dnd-edge-workspace-switch.trigger-height)
            (nullable leaf "delay-ms" cfg.gestures.dnd-edge-workspace-switch.delay-ms)
            (nullable leaf "max-speed" cfg.gestures.dnd-edge-workspace-switch.max-speed)
          ])
          (plain' "hot-corners" (toggle "off" cfg.gestures.hot-corners [ ]))
        ])

        (plain' "animations" [
          (toggle "off" cfg.animations [
            (nullable leaf "slowdown" cfg.animations.slowdown)
            (map (name: animation name cfg.animations.${name}) cfg.animations.all-anims)
          ])
        ])

        (plain' "xwayland-satellite" [
          (toggle "off" cfg.xwayland-satellite [
            (nullable leaf "path" cfg.xwayland-satellite.path)
          ])
        ])

        (map' plain' (lib.mapAttrsToList leaf) "debug" cfg.debug)
      ];
}
