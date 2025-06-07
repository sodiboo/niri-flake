{
  inputs,
  kdl,
  lib,
  docs,
  binds,
  settings,
  ...
}: {
  type = let
    inherit (lib) flip pipe showOption mkOption mkOptionType types;
    inherit (lib.types) nullOr attrsOf listOf submodule enum;

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

    float-or-int = types.either types.float types.int;

    variant = variants:
      mkOptionType {
        name = "variant";
        description =
          if variants == {}
          then "impossible (empty variant)"
          else "variant of: ${builtins.concatStringsSep " | " (builtins.attrNames variants)}";
        descriptionClass =
          if variants == {}
          then "noun"
          else "composite";

        check = v: let
          names = builtins.attrNames v;
          name = builtins.head names;
        in
          builtins.isAttrs v && builtins.length names == 1 && builtins.elem name (builtins.attrNames variants) && variants.${name}.check v.${name};

        merge = loc: definitions: let
          defs-for = name:
            pipe definitions [
              (builtins.filter (lib.hasAttrByPath ["value" name]))
              (map (def: def // {value = def.value.${name};}))
            ];
          merged = builtins.mapAttrs (name: type:
            type.merge (loc ++ [name]) (defs-for name))
          (lib.filterAttrs (name: _type: defs-for name != []) variants);
        in
          if merged == {}
          then throw "The option `${showOption loc}` has no definitions, but one is required"
          else if builtins.length (builtins.attrNames merged) == 1
          then merged
          else throw "The option `${showOption loc}` has conflicting definitions of multiple variants";

        nestedTypes = variants;

        inherit
          (record (builtins.mapAttrs (lib.const (type:
            (required type)
            // (lib.optionalAttrs (type ? variant-description) {
              description = type.variant-description;
            })))
          variants))
          getSubOptions
          ;
      };

    inherit (docs.lib) libinput-link libinput-doc link-niri-release link-this-github link' anchor' unstable-note;

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
      middle-emulation =
        optional types.bool false
        // {
          description = ''
            Whether a middle mouse button press should be sent when you press the left and right mouse buttons

            Further reading:
            - ${libinput-link "configuration" "Middle Button Emulation"}
            - ${libinput-link "middle-button-emulation" "Middle button emulation"}
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
      scroll-button =
        nullable types.int
        // {
          description = ''
            When `scroll-method = "on-button-down"`, this is the button that will be used to enable scrolling. This button must be on the same physical device as the pointer, according to libinput docs. The type is a button code, as defined in [`input-event-codes.h`](https://github.com/torvalds/linux/blob/e42b1a9a2557aa94fee47f078633677198386a52/include/uapi/linux/input-event-codes.h#L355-L363). Most commonly, this will be set to `BTN_LEFT`, `BTN_MIDDLE`, or `BTN_RIGHT`, or at least some mouse button, but any button from that file is a valid value for this option (though, libinput may not necessarily do anything useful with most of them)

            Further reading:
            - ${libinput-link "scrolling" "On-Button scrolling"}
          '';
        };
      scroll-method =
        nullable (types.enum ["no-scroll" "two-finger" "edge" "on-button-down"])
        // {
          description = ''
            When to convert motion events to scrolling events.
            The default and supported values vary based on the device type.

            Further reading:
            - ${libinput-link "scrolling" "Scrolling"}
          '';
        };
    };

    pointer-tablet-common = {
      enable = optional types.bool true;
      left-handed =
        optional types.bool false
        // {
          description = ''
            Whether to accomodate left-handed usage for this device.
            This varies based on the exact device, but will for example swap left/right mouse buttons.

            Further reading:
            - ${libinput-link "configuration" "Left-handed Mode"}
          '';
        };
    };

    preset-size = dimension: object:
      variant {
        fixed =
          types.int
          // {
            variant-description = ''
              The ${dimension} of the ${object} in logical pixels
            '';
          };
        proportion =
          types.float
          // {
            variant-description = ''
              The ${dimension} of the ${object} as a proportion of the screen's ${dimension}
            '';
          };
      };

    preset-width = preset-size "width" "column";
    preset-height = preset-size "height" "window";

    emptyOr = elemType:
      mkOptionType {
        name = "emptyOr";
        description =
          if builtins.elem elemType.descriptionClass ["noun" "conjunction"]
          then "{} or ${elemType.description}"
          else "{} or (${elemType.description})";
        descriptionClass = "conjunction";
        check = v: v == {} || elemType.check v;
        nestedTypes.elemType = elemType;
        merge = loc: defs:
          if builtins.all (def: def.value == {}) defs
          then {}
          else elemType.merge loc defs;

        inherit (elemType) getSubOptions;
      };

    default-width = emptyOr preset-width;
    default-height = emptyOr preset-height;

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
              The colorspace to interpolate the gradient in. This option is named `in'` because `in` is a reserved keyword in Nix.

              This is a subset of the [`<color-interpolation-method>`](https://developer.mozilla.org/en-US/docs/Web/CSS/color-interpolation-method) values in CSS.
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

              these beautiful images are sourced from the release notes for ${link-niri-release "v0.1.3"}
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

    decoration' = newtype (link-type "decoration") (decoration "<decoration>");

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
            optional float-or-int 4
            // {
              description = ''
                The width of the ${name} drawn around each ${window}.
              '';
            };
        }

        {
          active =
            optional decoration' {color = default-active-color;}
            // {
              visible = "shallow";
              description = ''
                The color of the ${name} for the window that has keyboard focus.
              '';
            };
          inactive =
            optional decoration' {color = "rgb(80 80 80)";}
            // {
              visible = "shallow";
              description = ''
                The color of the ${name} for windows that do not have keyboard focus.
              '';
            };
        }
      ]
      // {
        inherit description;
      };

    border-rule = {
      name,
      path,
      description,
      window,
    }:
      ordered-section [
        {
          enable =
            nullable types.bool
            // {
              description = ''
                Whether to enable the ${name}.
              '';
            };
          width =
            nullable float-or-int
            // {
              description = ''
                The width of the ${name} drawn around each ${window}.
              '';
            };
        }

        {
          active =
            nullable decoration'
            // {
              visible = "shallow";
              description = ''
                The color of the ${name} for the window that has keyboard focus.
              '';
            };
          inactive =
            nullable decoration'
            // {
              visible = "shallow";
              description = ''
                The color of the ${name} for windows that do not have keyboard focus.
              '';
            };
        }
      ]
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

      softness =
        nullable float-or-int
        // {
          description = shadow-descriptions.softness;
        };

      spread =
        nullable float-or-int
        // {
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

    shadow-descriptions = {
      offset = ''
        The offset of the shadow from the window, measured in logical pixels.

        This behaves like a [CSS box-shadow offset](https://developer.mozilla.org/en-US/docs/Web/CSS/box-shadow#syntax)
      '';

      softness = ''
        The softness/size of the shadow, measured in logical pixels.

        This behaves like a [CSS box-shadow blur-radius](https://developer.mozilla.org/en-US/docs/Web/CSS/box-shadow#syntax)
      '';

      spread = ''
        The spread of the shadow, measured in logical pixels.

        This behaves like a [CSS box-shadow spread radius](https://developer.mozilla.org/en-US/docs/Web/CSS/box-shadow#syntax)
      '';
    };

    regex = newtype (plain-type "regular expression") types.str;

    # the {window,layer} match rules are completely different from each other,
    # but i reckon "match rule" still makes sense for display name

    window-match = newtype (plain-type "match rule") (ordered-record [
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
        is-active-in-column =
          nullable types.bool
          // {
            description = ''
              When non-null, for this field to match a window, the value must match whether the window is active in its column or not.

              Every column has exactly one active-in-column window. If it is the active column, this window is also the active window. A column may not have zero active-in-column windows, or more than one active-in-column window.

              The active-in-column window is the window that was last focused in that column. When you switch focus to a column, the active-in-column window will be the new focused window.
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
        is-floating =
          nullable types.bool
          // {
            description = ''
              When not-null, for this field to match a window, the value must match whether the window is floating (true) or tiled (false).
            '';
          };
        is-window-cast-target =
          nullable types.bool
          // {
            description = ''
              When non-null, matches based on whether the window is being targeted by a window cast.
            '';
          };
      }
      {
        at-startup =
          nullable types.bool
          // {
            description = window-rule-descriptions.match-at-startup;
          };
      }
    ]);

    layer-match = newtype (plain-type "match rule") (ordered-record [
      {
        namespace =
          nullable regex
          // {
            description = ''
              A regular expression to match against the namespace of the layer surface.

              All layer surfaces have a namespace set once at creation. When this rule is non-null, the regex must match the namespace of the layer surface for this rule to match.
            '';
          };
      }
      {
        at-startup =
          nullable types.bool
          // {
            description = layer-rule-descriptions.match-at-startup;
          };
      }
    ]);

    rule-descriptions = {
      surface,
      surfaces,
      surface-rule,
      Surface-rules,
      example-fields,
      option,
    }: {
      top-option = ''
        ${Surface-rules}.

        A ${surface-rule} will match based on ${link' "programs.niri.settings.${option}.*.matches"} and ${link' "programs.niri.settings.${option}.*.excludes"}. Both of these are lists of "match rules".

        A given match rule can match based on one of several fields. For a given match rule to "match" a ${surface}, it must match on all fields.

        ${example-fields}

        - The `at_startup` field, when non-null, will match a ${surface} based on whether it was opened within the first 60 seconds of niri starting up.

        - If a field is null, it will always match.

        For a given ${surface-rule} to match a ${surface}, the above logic is employed to determine whether any given match rule matches, and the interactions between the match rules decide whether the ${surface-rule} as a whole will match. For a given ${surface-rule}:

        - A given ${surface} is "considered" if any of the match rules in ${link' "programs.niri.settings.${option}.*.matches"} successfully match this ${surface}. If all of the match rules do not match this ${surface}, then that ${surface} will never match this ${surface-rule}.

        - If ${link' "programs.niri.settings.${option}.*.matches"} contains no match rules, it will match any ${surface} and "consider" it for this ${surface-rule}.

        - If a given ${surface} is "considered" for this ${surface-rule} according to the above rules, the selection can be further refined with ${link' "programs.niri.settings.${option}.*.excludes"}. If any of the match rules in `excludes` match this ${surface}, it will be rejected and this ${surface-rule} will not match the given ${surface}.

        That is, a given ${surface-rule} will apply to a given ${surface} if any of the entries in ${link' "programs.niri.settings.${option}.*.matches"} match that ${surface} (or there are none), AND none of the entries in ${link' "programs.niri.settings.${option}.*.excludes"} match that ${surface}.

        All fields of a ${surface-rule} can be set to null, which represents that the field shall have no effect on the ${surface} (and in general, the client is allowed to choose the initial value).

        To compute the final set of ${surface-rule}s that apply to a given ${surface}, each ${surface-rule} in this list is consdered in order.

        At first, every field is set to null.

        Then, for each applicable ${surface-rule}:

        - If a given field is null on this ${surface-rule}, it has no effect. It does nothing and "inherits" the value from the previous rule.
        - If the given field is not null, it will overwrite the value from any previous rule.

        The "final value" of a field is simply its value at the end of this process. That is, the final value of a field is the one from the *last* ${surface-rule} that matches the given ${surface-rule} (not considering null entries, unless there are no non-null entries)

        If the final value of a given field is null, then it usually means that the client gets to decide. For more information, see the documentation for each field.
      '';

      match = ''
        A list of rules to match ${surfaces}.

        If any of these rules match a ${surface} (or there are none), that ${surface-rule} will be considered for this ${surface}. It can still be rejected by ${link' "programs.niri.settings.${option}.*.excludes"}

        If all of the rules do not match a ${surface}, then this ${surface-rule} will not apply to that ${surface}.
      '';

      exclude = ''
        A list of rules to exclude ${surfaces}.

        If any of these rules match a ${surface}, then this ${surface-rule} will not apply to that ${surface}, even if it matches one of the rules in ${link' "programs.niri.settings.${option}.*.matches"}

        If none of these rules match a ${surface}, then this ${surface-rule} will not be rejected. It will apply to that ${surface} if and only if it matches one of the rules in ${link' "programs.niri.settings.${option}.*.matches"}
      '';

      match-at-startup = ''
        When true, this rule will match ${surfaces} opened within the first 60 seconds of niri starting up. When false, this rule will match ${surfaces} opened *more than* 60 seconds after niri started up. This is useful for applying different rules to ${surfaces} opened from ${link' "programs.niri.settings.spawn-at-startup"} versus those opened later.
      '';

      opacity = ''
        The opacity of the ${surface}, ranging from 0 to 1.

        If the final value of this field is null, niri will fall back to a value of 1.

        Note that this is applied in addition to the opacity set by the client. Setting this to a semitransparent value on a ${surface} that is already semitransparent will make it even more transparent.
      '';

      block-out-from = ''
        Whether to block out this ${surface} from screen captures. When the final value of this field is null, it is not blocked out from screen captures.

        This is useful to protect sensitive information, like the contents of password managers or private chats. It is very important to understand the implications of this option, as described below, **especially if you are a streamer or content creator**.

        Some of this may be obvious, but in general, these invariants *should* hold true:
        - a ${surface} is never meant to be blocked out from the actual physical screen (otherwise you wouldn't be able to see it at all)
        - a `block-out-from` ${surface} *is* meant to be always blocked out from screencasts (as they are often used for livestreaming etc)
        - a `block-out-from` ${surface} is *not* supposed to be blocked from screenshots (because usually these are not broadcasted live, and you generally know what you're taking a screenshot of)

        There are three methods of screencapture in niri:

        1. The `org.freedesktop.portal.ScreenCast` interface, which is used by tools like OBS primarily to capture video. When `block-out-from = "screencast";` or `block-out-from = "screen-capture";`, this ${surface} is blocked out from the screencast portal, and will not be visible to screencasting software making use of the screencast portal.

        1. The `wlr-screencopy` protocol, which is used by tools like `grim` primarily to capture screenshots. When `block-out-from = "screencast";`, this protocol is not affected and tools like `grim` can still capture the ${surface} just fine. This is because you may still want to take a screenshot of such ${surfaces}. However, some screenshot tools display a fullscreen overlay with a frozen image of the screen, and then capture that. This overlay is *not* blocked out in the same way, and may leak the ${surface} contents to an active screencast. When `block-out-from = "screen-capture";`, this ${surface} is blocked out from `wlr-screencopy` and thus will never leak in such a case, but of course it will always be blocked out from screenshots and (sometimes) the physical screen.

        1. The built in `screenshot` action, implemented in niri itself. This tool works similarly to those based on `wlr-screencopy`, but being a part of the compositor gets superpowers regarding secrecy of ${surface} contents. Its frozen overlay will never leak ${surface} contents to an active screencast, because information of blocked ${surfaces} and can be distinguished for the physical output and screencasts. `block-out-from` does not affect the built in screenshot tool at all, and you can always take a screenshot of any ${surface}.

        | `block-out-from` | can `ScreenCast`? | can `screencopy`? | can `screenshot`? |
        | --- | :---: | :---: | :---: |
        | `null` | yes | yes | yes |
        | `"screencast"` | no | yes | yes |
        | `"screen-capture"` | no | no | yes |

        > [!caution]
        > **Streamers: Do not accidentally leak ${surface} contents via screenshots.**
        >
        > For ${surfaces} where `block-out-from = "screencast";`, contents of a ${surface} may still be visible in a screencast, if the ${surface} is indirectly displayed by a tool using `wlr-screencopy`.
        >
        > If you are a streamer, either:
        > - make sure not to use `wlr-screencopy` tools that display a preview during your stream, or
        > - **set `block-out-from = "screen-capture";` to ensure that the ${surface} is never visible in a screencast.**

        > [!caution]
        > **Do not let malicious `wlr-screencopy` clients capture your top secret ${surfaces}.**
        >
        > (and don't let malicious software run on your system in the first place, you silly goose)
        >
        > For ${surfaces} where `block-out-from = "screencast";`, contents of a ${surface} will still be visible to any application using `wlr-screencopy`, even if you did not consent to this application capturing your screen.
        >
        > Note that sandboxed clients restricted via security context (i.e. Flatpaks) do not have access to `wlr-screencopy` at all, and are not a concern.
        >
        > **If a ${surface}'s contents are so secret that they must never be captured by any (non-sandboxed) application, set `block-out-from = "screen-capture";`.**

        Essentially, use `block-out-from = "screen-capture";` if you want to be sure that the ${surface} is never visible to any external tool no matter what; or use `block-out-from = "screencast";` if you want to be able to capture screenshots of the ${surface} without its contents normally being visible in a screencast. (at the risk of some tools still leaking the ${surface} contents, see above)
      '';
    };

    window-rule-descriptions = rule-descriptions {
      surface = "window";
      surfaces = "windows";
      surface-rule = "window rule";
      Surface-rules = "Window rules";
      option = "window-rules";

      example-fields = ''
        - The `title` field, when non-null, is a regular expression. It will match a window if the client has set a title and its title matches the regular expression.

        - The `app-id` field, when non-null, is a regular expression. It will match a window if the client has set an app id and its app id matches the regular expression.
      '';
    };

    layer-rule-descriptions = rule-descriptions {
      surface = "layer surface";
      surfaces = "layer surfaces";
      surface-rule = "layer rule";
      Surface-rules = "Layer rules";
      option = "layer-rules";

      example-fields = ''
        - The `namespace` field, when non-null, is a regular expression. It will match a layer surface for which the client has set a namespace that matches the regular expression.
      '';
    };

    alphabetize = sections:
      lib.mergeAttrsList (lib.imap0 (i: section: {
          ${builtins.elemAt lib.strings.lowerChars i} = section;
        })
        sections);

    ordered-record = sections: let
      grouped = lib.groupBy (s:
        if s ? __module
        then "module"
        else if s ? __config
        then "config"
        else "options")
      sections;

      options' = grouped.options or [];
      config' = map (builtins.getAttr "__config") grouped.config or [];
      module' = map (builtins.getAttr "__module") grouped.module or [];

      normalize = map (flip removeAttrs ["__docs-only"]);
      real-sections-flat = pipe options' [
        (builtins.filter (s: !(s.__docs-only or false)))
        normalize
        lib.mergeAttrsList
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
              config = lib.mkMerge (map (f:
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
        getSubOptions = loc: lib.mapAttrs (_section: opts: (record opts).getSubOptions loc) ord-sections;
      };

    make-section = flip optional {};

    section = flip pipe [record make-section];
    ordered-section = flip pipe [ordered-record make-section];
  in
    ordered-record [
      {
        switch-events = let
          switch-bind = newtype (plain-type "niri switch bind") (record {
            action =
              required (newtype (plain-type "niri switch action") kdl.types.kdl-leaf)
              // {
                description = ''
                  A switch action is represented as an attrset with a single key, being the name, and a value that is a list of its arguments.

                  See also ${link' "programs.niri.settings.binds.<name>.action"} for more information on how this works, it has the exact same option type. Beware that switch binds are not the same as regular binds, and the actions they take are different. Currently, they can only accept spawn binds. Correct usage is like so:

                  ```nix
                  {
                    programs.niri.settings.switch-events = {
                      tablet-mode-on.action.spawn = ["gsettings" "set" "org.gnome.desktop.a11y.applications" "screen-keyboard-enabled" "true"];
                      tablet-mode-off.action.spawn = ["gsettings" "set" "org.gnome.desktop.a11y.applications" "screen-keyboard-enabled" "false"];
                    };
                  }
                  ```
                '';
              };
          });

          switch-bind' =
            nullable (newtype (link-type "switch-bind") switch-bind)
            // {
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
              __docs-only = true;
              "<switch-bind>" =
                required switch-bind
                // {
                  override-loc = lib.const ["<switch-bind>"];
                  description = ''
                    <!--
                    This description doesn't matter to the docs, but is necessary to make this header actually render so the above types can link to it.
                    -->
                  '';
                };
            }
          ];
        binds = let
          base = record {
            allow-when-locked =
              optional types.bool false
              // {
                description = ''
                  Whether this keybind should be allowed when the screen is locked.

                  This is only applicable for `spawn` keybinds.
                '';
              };
            allow-inhibiting =
              optional types.bool true
              // {
                description = ''
                  When a surface is inhibiting keyboard shortcuts, this option dictates wether *this* keybind will be inhibited as well.

                  By default it is true for all keybinds, meaning an application can block this keybind from being triggered, and the application will receive the key event instead.

                  When false, this keybind will always be triggered, even if an application is inhibiting keybinds. There is no way for a client to observe this keypress.

                  Has no effect when `action` is `toggle-keyboard-shortcuts-inhibit`. In that case, this value is implicitly false, no matter what you set it to. (note that the value reported in the nix config may be inaccurate in that case; although hopefully you're not relying on the values of specific keybinds for the rest of your config?)
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
            repeat =
              optional types.bool true
              // {
                description = ''
                  Whether this keybind should trigger repeatedly when held down.
                '';
              };
            hotkey-overlay =
              optional (variant {
                hidden =
                  types.bool
                  // {
                    variant-description = ''
                      When `true`, the hotkey overlay will not contain this keybind at all. When `false`, it will show the default title of the action.
                    '';
                  };
                title =
                  types.str
                  // {
                    variant-description = ''
                      The title of this keybind in the hotkey overlay. [Pango markup](https://docs.gtk.org/Pango/pango_markup.html) is supported.
                    '';
                  };
              }) {
                hidden = false;
              }
              // {
                description = ''
                  How this keybind should be displayed in the hotkey overlay.

                  - By default, `{hidden = false;}` maps to omitting this from the KDL config; the default title of the action will be used.
                  - `{hidden = true;}` will emit `hotkey-overlay-title=null` in the KDL config, and the hotkey overlay will not contain this keybind at all.
                  - `{title = "foo";}` will emit `hotkey-overlay-title="foo"` in the KDL config, and the hotkey overlay will show "foo" as the title of this keybind.
                '';
              };
            action =
              required (newtype (plain-type "niri action") kdl.types.kdl-leaf)
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
                    Required fields are marked with `*` before their name, and if no fields are required, you can use the action without any arguments too (see `quit` in the example above). \
                    If a field is marked with `?`, then omitting it is meaningful. (without `?`, it will have a default value)

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
                      is-stable = builtins.any (a: a.name == name) binds-stable;
                      is-unstable = builtins.any (a: a.name == name) binds-unstable;
                      exclusive =
                        if is-stable && is-unstable
                        then ""
                        else if is-stable
                        then " (only on niri-stable)"
                        else " (only on niri-unstable)";
                      type-names = {
                        LayoutSwitchTarget = ''"next" | "prev"'';
                        WorkspaceReference = "u8 | string";
                        SizeChange = "size-change";
                        bool = "bool";
                        u8 = "u8";
                        u16 = "u16";
                        String = "string";
                      };

                      type-or = rust-name: fallback: type-names.${rust-name} or (lib.warn "unhandled type `${rust-name}`" fallback);

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
                        prop = lambda "{ ${lib.optionalString (!params.use-default) "*"}${params.field}${lib.optionalString params.none-important "?"} :: ${type-names.${params.type} or (lib.warn "unhandled type `${params.type}`" params.type)} }";
                        unknown = ''
                          ${lambda "unknown"}

                            The code that generates this documentation does not know how to parse the definition:
                            ```rs
                            ${params.raw-params})
                            ```
                        '';
                      }
                      .${
                        params.kind
                      }
                      or (abort "action `${name}` with unhandled kind `${params.kind}` for settings docs");
                  in
                    builtins.concatStringsSep "\n" (builtins.concatLists [
                      (map show-bind (builtins.filter (stable: builtins.all (unstable: stable.name != unstable.name) binds-unstable) binds-stable))
                      (map show-bind binds-unstable)
                    ])}
                '';
              };
          };

          bind = mkOptionType {
            inherit (base) name getSubOptions nestedTypes;
            description = "niri keybind";
            descriptionClass = "noun";
            check = v: builtins.isString v || builtins.isAttrs v || base.check v;
            merge = loc: defs:
              base.merge loc (map (def:
                def
                // {
                  value =
                    if def.value ? action
                    then def.value
                    else
                      lib.warn ''

                        Deprecated definition of binds used for ${showOption loc}

                        New properties in niri require a new schema.

                        Replace binds like `programs.niri.settings.binds."Mod+T".spawn = "alacritty";` with `programs.niri.settings.binds."Mod+T".action.spawn = "alacritty";`.

                        String actions will also not be supported anymore.

                        Replace binds like `programs.niri.settings."Mod+Q" = "close-window";` with `programs.niri.settings.binds."Mod+Q".action.close-window = [];`.

                        This is not an error, and your configuration will still work, but this will not continue to be the case in the future.

                        Please see the documentation on GitHub for more information: ${link-this-github "docs.md#${anchor' "programs.niri.settings.binds"}"}
                      ''
                      (
                        if builtins.isString def.value
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
        clipboard.disable-primary =
          optional types.bool false
          // {
            description = ''
              The "primary selection" is a special clipboard that contains the text that was last selected with the mouse, and can usually be pasted with the middle mouse button.

              This is a feature that is not inherently part of the core Wayland protocol, but [a widely supported protocol extension](https://wayland.app/protocols/primary-selection-unstable-v1#compositor-support) enables support for it anyway.

              This functionality was inherited from X11, is not necessarily intuitive to many users; especially those coming from other operating systems that do not have this feature (such as Windows, where the middle mouse button is used for scrolling).

              If you don't want to have a primary selection, you can disable it with this option. Doing so will prevent niri from adveritising support for the primary selection protocol.

              Note that this option has nothing to do with the "clipboard" that is commonly invoked with `Ctrl+C` and `Ctrl+V`.
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
        workspaces =
          attrs (record {
            name =
              nullable types.str
              // {
                description = ''
                  An (optional) name for the workspace. Defaults to the value of the key.

                  This attribute is intended to be used when you wish to preserve a specific
                  order for the named workspaces.
                '';
              };
            open-on-output =
              nullable types.str
              // {
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

              ```nix
              {
                programs.niri.settings.workspaces."name" = {};
                programs.niri.settings.workspaces."01-another-one" = {
                  open-on-output = "DP-1";
                  name = "another-one";
                };
              }
              ```

              Unless a `name` is declared, the workspace will use the attribute key as the name.

              Workspaces will be created in a specific order: sorted by key. If you do not care
              about the order of named workspaces, you can skip using the `name` attribute, and
              use the key instead. If you do care about it, you can use the key to order them,
              and a `name` attribute to have a friendlier name.
            '';
          };
      }

      {
        overview = {
          zoom =
            nullable float-or-int
            // {
              description = ''
                Control how much the workspaces zoom out in the overview. zoom ranges from 0 to 0.75 where lower values make everything smaller.
              '';
            };
          backdrop-color =
            nullable types.str
            // {
              description = ''
                Set the backdrop color behind workspaces in the overview. The backdrop is also visible between workspaces when switching.

                The alpha channel for this color will be ignored.
              '';
            };
        };
      }

      {
        input = {
          keyboard = {
            xkb = let
              arch-man-xkb = anchor: "[`xkeyboard-config(7)`](https://man.archlinux.org/man/xkeyboard-config.7#${anchor})";

              default-env = default: field: ''
                If this is set to ${default}, the ${field} will be read from the `XKB_DEFAULT_${lib.toUpper field}` environment variable.
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
              ordered-section [
                {
                  file =
                    nullable types.str
                    // {
                      description = ''
                        Path to a `.xkb` keymap file. If set, this file will be used to configure libxkbcommon, and all other options will be ignored.
                      '';
                    };
                }
                base
              ]
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
            pointer-tablet-common
            // basic-pointer true
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
              drag-lock =
                optional types.bool false
                // {
                  description = ''
                    On most touchpads, tap and drag is enabled by default.

                    Tap and drag means that to drag an item, you tap the touchpad with some amount of fingers to decide what kind of button press is emulated, but don't hold those fingers, and then you immediately start dragging with one finger.

                    By default, a "tap and drag" gesture is terminated by releasing the finger that is dragging.

                    Drag lock means that the drag gesture is not terminated when the finger is released, but only when the finger is tapped again, or after a timeout (unless sticky mode is enabled). This allows you to reset your finger position without losing the drag gesture.

                    Drag lock is only applicable for devices where tap and drag is also enabled.

                    Further reading:
                    - ${libinput-link "tapping" "Tap-and-drag"}
                  '';
                };

              disabled-on-external-mouse =
                optional types.bool false
                // {
                  description = ''
                    Whether to disable the touchpad when an external mouse is plugged in.

                    Further reading:
                    - ${libinput-link "configuration" "Send Events Mode"}
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

              scroll-factor =
                nullable types.float
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
                nullable types.float
                // {
                  description = ''
                    For all scroll events triggered by a wheel source, the scroll distance is multiplied by this factor.

                    This is not a libinput property, but rather a niri-specific one.
                  '';
                };
            };
          trackpoint = pointer-tablet-common // basic-pointer false;
          trackball = pointer-tablet-common // basic-pointer false;
          tablet =
            pointer-tablet-common
            // {
              map-to-output = nullable types.str;
              calibration-matrix =
                nullable (mkOptionType {
                  name = "matrix";
                  description = "2x3 matrix";
                  check = matrix:
                    builtins.isList matrix
                    && builtins.length matrix == 2
                    && builtins.all (
                      row:
                        builtins.isList row
                        && builtins.length row == 3
                        && builtins.all builtins.isFloat row
                    )
                    matrix;
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
                    ```nix
                    {
                      # 90 degree rotation clockwise
                      calibration-matrix = [
                        [ 0.0 -1.0 1.0 ]
                        [ 1.0  0.0 0.0 ]
                      ];
                    }
                    ```

                    Further reading:
                    - [`libinput_device_config_calibration_get_default_matrix()`](https://wayland.freedesktop.org/libinput/doc/1.8.2/group__config.html#ga3d9f1b9be10e804e170c4ea455bd1f1b)
                    - [`libinput_device_config_calibration_set_matrix()`](https://wayland.freedesktop.org/libinput/doc/1.8.2/group__config.html#ga09a798f58cc601edd2797780096e9804)
                    - [rustdoc because libinput's web docs are an eyesore](https://smithay.github.io/smithay/input/struct.Device.html#method.config_calibration_set_matrix)
                  '';
                };
            };
          touch.map-to-output = nullable types.str;
          warp-mouse-to-focus =
            optional types.bool false
            // {
              description = ''
                Whether to warp the mouse to the focused window when switching focus.
              '';
            };
          focus-follows-mouse.enable =
            optional types.bool false
            // {
              description = ''
                Whether to focus the window under the mouse when the mouse moves.
              '';
            };
          focus-follows-mouse.max-scroll-amount =
            nullable types.str
            // {
              description = ''
                The maximum proportion of the screen to scroll at a time
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
          backdrop-color =
            nullable types.str
            // {
              description = ''
                ${unstable-note}

                The backdrop color that niri draws for this output. This is visible between workspaces or in the overview.
              '';
            };
          background-color =
            nullable types.str
            // {
              description = ''
                The background color of this output. This is equivalent to launching `swaybg -c <color>` on that output, but is handled by the compositor itself for solid colors.
              '';
            };
          scale =
            nullable float-or-int
            // {
              description = ''
                The scale of this output, which represents how many physical pixels fit in one logical pixel.

                If this is null, niri will automatically pick a scale for you.
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
            optional (enum [false "on-demand" true]) false
            // {
              description = ''
                Whether to enable variable refresh rate (VRR) on this output.

                VRR is also known as Adaptive Sync, FreeSync, and G-Sync.

                Setting this to `"on-demand"` will enable VRR only when a window with ${link' "programs.niri.settings.window-rules.*.variable-refresh-rate"} is present on this output.
              '';
            };
        });
      }

      {
        cursor = section ({...}: {
          imports = [
            (lib.mkRenamedOptionModule ["hide-on-key-press"] ["hide-when-typing"])
          ];
          options = {
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
            hide-when-typing =
              optional types.bool false
              // {
                description = ''
                  Whether to hide the cursor when typing.
                '';
              };
            hide-after-inactive-ms =
              nullable types.int
              // {
                description = ''
                  If set, the cursor will automatically hide once this number of milliseconds passes since the last cursor movement.
                '';
              };
          };
        });
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
            shadow = section {
              enable = optional types.bool false;
              offset =
                section {
                  x = optional float-or-int 0.0;
                  y = optional float-or-int 5.0;
                }
                // {
                  description = shadow-descriptions.offset;
                };

              softness =
                optional float-or-int 30.0
                // {
                  description = shadow-descriptions.softness;
                };

              spread =
                optional float-or-int 5.0
                // {
                  description = shadow-descriptions.spread;
                };

              draw-behind-window = optional types.bool false;

              # 0x70 is 43.75% so let's use hex notation lol
              color = optional types.str "#00000070";

              inactive-color = nullable types.str;
            };
          }
          {
            insert-hint =
              ordered-section [
                {
                  enable =
                    optional types.bool true
                    // {
                      description = ''
                        Whether to enable the insert hint.
                      '';
                    };
                }
                {
                  display =
                    optional decoration' {color = "rgb(127 200 255 / 50%)";}
                    // {
                      visible = "shallow";
                      description = ''
                        The color of the insert hint.
                      '';
                    };
                }
              ]
              // {
                description = ''
                  The insert hint is a decoration drawn *between* windows during an interactive move operation. It is drawn in the gap where the window will be inserted when you release the window. It does not occupy any space in the gap, and the insert hint extends onto the edges of adjacent windows. When you release the moved window, the windows that are covered by the insert hint will be pushed aside to make room for the moved window.
                '';
              };
          }
          {
            __docs-only = true;
            decoration =
              required (decoration "<decoration>")
              // {
                override-loc = lib.const ["<decoration>"];
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
                    programs.niri.settings.layout.preset-column-widths = [
                      { proportion = 1. / 3.; }
                      { proportion = 1. / 2.; }
                      { proportion = 2. / 3.; }

                      # { fixed = 1920; }
                    ];
                  }
                  ```
                '';
              };
            preset-window-heights =
              list preset-height
              // {
                description = ''
                  The heights that `switch-preset-window-height` will cycle through.

                  Each height can either be a fixed height in logical pixels, or a proportion of the screen's height.

                  Example:

                  ```nix
                  {
                    programs.niri.settings.layout.preset-window-heights = [
                      { proportion = 1. / 3.; }
                      { proportion = 1. / 2.; }
                      { proportion = 2. / 3.; }

                      # { fixed = 1080; }
                    ];
                  }
                  ```
                '';
              };
          }
          {
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
            always-center-single-column =
              optional types.bool false
              // {
                description = ''
                  This is like `center-focused-column = "always";`, but only for workspaces with a single column. Changes nothing is `center-focused-column` is set to `"always"`. Has no effect if more than one column is present.
                '';
              };
            default-column-display =
              optional (enum ["normal" "tabbed"]) "normal"
              // {
                description = ''
                  How windows in columns should be displayed by default.

                  - `"normal"`: Windows are arranged vertically, spread across the working area height.
                  - `"tabbed"`: Windows are arranged in tabs, with only the focused window visible, taking up the full height of the working area.

                  Note that you can override this for a given column at any time. Every column remembers its own display mode, independent from this setting. This setting controls the default value when a column is *created*.

                  Also, since a newly created column always contains a single window, you can override this default value with ${link' "programs.niri.settings.window-rules.*.default-column-display"}.
                '';
              };

            tab-indicator = nullable (ordered-record [
              {
                enable = optional types.bool true;
                hide-when-single-tab = optional types.bool false;
                place-within-column = optional types.bool false;
                gap = optional float-or-int 5.0;
                width = optional float-or-int 4.0;
                length.total-proportion = optional types.float 0.5;
                position = optional (enum ["left" "right" "top" "bottom"]) "left";
                gaps-between-tabs = optional float-or-int 0.0;
                corner-radius = optional float-or-int 0.0;
              }
              (
                let
                  this-fucking-type = state: let
                    # this is the real, semantic type of the value.
                    # and semantically, it has a default value of the corresponding border decoration.
                    # but, it's painful/infeasible to find that value here,
                    # so we make niri do it for us.
                    # and to do so, we set it to **null** by default.
                    real = decoration "<decoration>";

                    # don't you dare call yourself nullable.
                    bullshit-mess = optional (newtype (link-type "decoration") (newtype real (nullOr real) // {inherit (real) name;})) null;
                  in
                    bullshit-mess
                    // {
                      visible = "shallow";
                      defaultText = "config.programs.niri.settings.layout.border.${state}";
                    };
                in {
                  active =
                    this-fucking-type "active"
                    // {
                      description = ''
                        The color of the tab indicator for the window that has keyboard focus.
                      '';
                    };
                  inactive =
                    this-fucking-type "inactive"
                    // {
                      description = ''
                        The color of the the tab indicator for windows that do not have keyboard focus.
                      '';
                    };
                }
              )
            ]);
          }
          {
            empty-workspace-above-first =
              optional types.bool false
              // {
                description = ''
                  Normally, niri has a dynamic amount of workspaces, with one empty workspace at the end. The first workspace really  is the first workspace, and you cannot go past it, but going past the last workspace puts you on the empty workspace.

                  When this is enabled, there will be an empty workspace above the first workspace, and you can go past the first workspace to get to an empty workspace, just as in the other direction. This makes workspace navigation symmetric in all ways except indexing.
                '';
              };
            gaps =
              optional float-or-int 16
              // {
                description = ''
                  The gap between windows in the layout, measured in logical pixels.
                '';
              };
            struts =
              section {
                left = optional float-or-int 0;
                right = optional float-or-int 0;
                top = optional float-or-int 0;
                bottom = optional float-or-int 0;
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
                required (enum ["linear" "ease-out-quad" "ease-out-cubic" "ease-out-expo"])
                // {
                  description = ''
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
            window-movement.spring = {
              damping-ratio = 1.0;
              stiffness = 800;
              epsilon = 0.0001;
            };
            window-open.easing = {
              duration-ms = 150;
              curve = "ease-out-expo";
            };
            window-close.easing = {
              duration-ms = 150;
              curve = "ease-out-quad";
            };
            window-resize.spring = {
              damping-ratio = 1.0;
              stiffness = 800;
              epsilon = 0.0001;
            };
            screenshot-ui-open.easing = {
              duration-ms = 200;
              curve = "ease-out-quad";
            };
          };
        in
          ordered-section [
            {
              enable = optional types.bool true;
              slowdown = optional types.float 1.0;
            }
            (builtins.mapAttrs (lib.const (v:
              optional (nullOr (newtype (link-type "animation") animation)) (removeAttrs v ["unstable"])
              // {visible = "shallow";}
              // lib.optionalAttrs (v.unstable or false) {
                description = ''
                  ${unstable-note}
                '';
              }))
            defaults)
            {
              shaders =
                section {
                  window-open = nullable types.str;
                  window-close = nullable types.str;
                  window-resize = nullable types.str;
                }
                // {
                  description = ''
                    These options should contain the *source code* for GLSL shaders.

                    See: https://github.com/YaLTeR/niri/wiki/Configuration:-Animations#custom-shader
                  '';
                };
            }
            {
              __module = {
                config,
                options,
                ...
              }: {
                options._internal_niri_flake =
                  readonly
                  (record (
                    lib.concatMapAttrs (name:
                      lib.const {
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
                  override-loc = lib.const ["<animation>"];
                };
            }
          ];

        gestures = nullable (record {
          dnd-edge-view-scroll = {
            trigger-width =
              optional float-or-int 30.0
              // {
                description = ''
                  The width of the edge of the screen where dragging a window will scroll the view.
                '';
              };
            delay-ms =
              optional types.int 100
              // {
                description = ''
                  The delay in milliseconds before the view starts scrolling.
                '';
              };
            max-speed =
              optional float-or-int 1500.0
              // {
                description = ''
                  When the cursor is at boundary of the trigger width, the view will not be scrolling. Moving the mouse further away from the boundary and closer to the egde will linearly increase the scrolling speed, until the mouse is pressed against the edge of the screen, at which point the view will scroll at this speed. The speed is measured in logical pixels per second.
                '';
              };
          };
          hot-corners = {
            enable =
              nullable types.bool
              // {
                description = ''
                  Put your mouse at the very top-left corner of a monitor to toggle the overview. Also works during drag-and-dropping something.
                '';
              };
          };
        });
      }

      {
        environment =
          attrs (nullOr types.str)
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
                  list window-match
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
                  list window-match
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
                      The default width for new columns.

                      If the final value of this option is null, it default to ${link' "programs.niri.settings.layout.default-column-width"}

                      If the final value option is not null, then its value will take priority over ${link' "programs.niri.settings.layout.default-column-width"} for windows matching this rule.

                      An empty attrset `{}` is not the same as null. When this is set to an empty attrset `{}`, windows will get to decide their initial width. When set to null, it represents that this particular window rule has no effect on the default width (and it should instead be taken from an earlier rule or the global default).

                    '';
                  };
                default-window-height =
                  nullable default-height
                  // {
                    description = ''
                      The default height for new floating windows.

                      This does nothing if the window is not floating when it is created.

                      There is no global default option for this in the layout section like for the column width. If the final value of this option is null, then it defaults to the empty attrset `{}`.

                      If this is set to an empty attrset `{}`, then it effectively "unsets" the default height for this window rule evaluation, as opposed to `null` which doesn't change the value at all. Future rules may still set it to a value and unset it again as they wish.

                      If the final value of this option is an empty attrset `{}`, then the client gets to decide the height of the window.

                      If the final value of this option is not an empty attrset `{}`, and the window spawns as floating, then the window will be created with the specified height.
                    '';
                  };
                default-column-display =
                  nullable (enum ["normal" "tabbed"])
                  // {
                    description = ''
                      When this window is inserted into the tiling layout such that a new column is created (e.g. when it is first opened, when it is expelled from an existing column, when it's moved to a new workspace, etc), this setting controls the default display mode of the column.

                      If the final value of this field is null, then the default display mode is taken from ${link' "programs.niri.settings.layout.default-column-display"}.
                    '';
                  };
              }
              {
                open-on-output =
                  nullable types.str
                  // {
                    description = ''
                      The output to open this window on.

                      If final value of this field is an output that exists, the new window will open on that output.

                      If the final value is an output that does not exist, or it is null, then the window opens on the currently focused output.
                    '';
                  };
                open-on-workspace =
                  nullable types.str
                  // {
                    description = ''
                      The workspace to open this window on.

                      If the final value of this field is a named workspace that exists, the window will open on that workspace.

                      If the final value of this is a named workspace that does not exist, or it is null, the window opens on the currently focused workspace.
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
                open-floating =
                  nullable types.bool
                  // {
                    description = ''
                      Whether to open this window as floating.

                      If the final value of this field is true, then this window will always be forced to open as floating.

                      If the final value of this field is false, then this window is never allowed to open as floating.

                      If the final value of this field is null, then niri will decide whether to open the window as floating or as tiled.
                    '';
                  };

                open-focused =
                  nullable types.bool
                  // {
                    description = ''
                      Whether to focus this window when it is opened.

                      If the final value of this field is null, then the window will be focused based on several factors:

                      - If it provided a valid activation token that hasn't expired, it will be focused.
                      - If the strict activation policy is enabled (not by default), the procedure ends here. It will be focused if and only if the activation token is valid.
                      - Otherwise, if no valid activation token was presented, but the window is a dialog, it will open next to its parent and be focused anyways.
                      - If the window is not a dialog, it will be focused if there is no fullscreen window; we don't want to steal its focus unless a dialog belongs to it.

                      (a dialog here means a toplevel surface that has a non-null parent)

                      If the final value of this field is not null, all of the above is ignored. Whether the window provides an activation token or not, doesn't matter. The window will be focused if and only if this field is true. If it is false, the window will not be focused, even if it provides a valid activation token.
                    '';
                  };
              }
              {
                block-out-from =
                  nullable (enum ["screencast" "screen-capture"])
                  // {
                    description = window-rule-descriptions.block-out-from;
                  };

                geometry-corner-radius =
                  geometry-corner-radius-rule
                  // {
                    description = ''
                      The corner radii of the window decorations (border, focus ring, and shadow) in logical pixels.

                      By default, the actual window surface will be unaffected by this.

                      Set ${link' "programs.niri.settings.window-rules.*.clip-to-geometry"} to true to clip the window to its visual geometry, i.e. apply the corner radius to the window surface itself.
                    '';
                  };

                clip-to-geometry =
                  nullable types.bool
                  // {
                    description = ''
                      Whether to clip the window to its visual geometry, i.e. whether the corner radius should be applied to the window surface itself or just the decorations.
                    '';
                  };

                border = border-rule {
                  name = "border";
                  window = "matched window";
                  path = "programs.niri.settings.window-rules.*.border";
                  description = ''
                    See ${link' "programs.niri.settings.layout.border"}.
                  '';
                };
                focus-ring = border-rule {
                  name = "focus ring";
                  window = "matched window with focus";
                  path = "programs.niri.settings.window-rules.*.focus-ring";
                  description = ''
                    See ${link' "programs.niri.settings.layout.focus-ring"}.
                  '';
                };

                tab-indicator = {
                  active =
                    nullable decoration'
                    // {
                      visible = "shallow";
                      description = ''
                        See ${link' "programs.niri.settings.layout.tab-indicator.active"}.
                      '';
                    };
                  inactive =
                    nullable decoration'
                    // {
                      visible = "shallow";
                      description = ''
                        See ${link' "programs.niri.settings.layout.tab-indicator.inactive"}.
                      '';
                    };
                };

                shadow = shadow-rule;
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
                    description = window-rule-descriptions.opacity;
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
              {
                baba-is-float =
                  nullable types.bool
                  // {
                    description = ''
                      Makes your window FLOAT up and down, like in the game Baba Is You.

                      Made for April Fools 2025.
                    '';
                  };
                default-floating-position =
                  nullable (record {
                    x = required float-or-int;
                    y = required float-or-int;
                    relative-to = required (enum ["top-left" "top-right" "bottom-left" "bottom-right" "top" "bottom" "left" "right"]);
                  })
                  // {
                    description = ''
                      The default position for this window when it enters the floating layout.

                      If a window is created as floating, it will be placed at this position.

                      If a window is created as tiling, then later made floating, it will be placed at this position.

                      If a window has already been placed as floating through one of the above methods, and moved back to the tiling layout, then this option has no effect the next time it enters the floating layout. It will be placed at the same position it was last time.

                      The `x` and `y` fields are the distances from the edge of the screen to the edge of the window, in logical pixels. The `relative-to` field determines which two edges of the window and screen that these distances are measured from.
                    '';
                  };
              }
              {
                variable-refresh-rate =
                  nullable types.bool
                  // {
                    description = ''
                      Takes effect only when the window is on an output with ${link' "programs.niri.settings.outputs.*.variable-refresh-rate"} set to `"on-demand"`. If the final value of this field is true, then the output will enable variable refresh rate when this window is present on it.
                    '';
                  };
              }
              {
                scroll-factor = nullable float-or-int;
              }
            ]
            // {
              description = "window rule";
              descriptionClass = "noun";
            })
          // {
            description = window-rule-descriptions.top-option;
          };
      }

      {
        layer-rules =
          list (ordered-record [
              {
                matches =
                  list layer-match
                  // {
                    description = layer-rule-descriptions.match;
                  };
              }
              {
                excludes =
                  list layer-match
                  // {
                    description = layer-rule-descriptions.exclude;
                  };
              }
              {
                block-out-from =
                  nullable (enum ["screencast" "screen-capture"])
                  // {
                    description = window-rule-descriptions.block-out-from;
                  };

                opacity =
                  nullable types.float
                  // {
                    description = window-rule-descriptions.opacity;
                  };
              }
              {
                shadow = shadow-rule;
                geometry-corner-radius =
                  geometry-corner-radius-rule
                  // {
                    description = ''
                      The corner radii of the surface decorations (shadow) in logical pixels.
                    '';
                  };
              }
            ]
            // {
              description = "layer rule";
              descriptionClass = "noun";
            })
          // {
            description = layer-rule-descriptions.top-option;
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

  module = {config, ...}: let
    cfg = config.programs.niri;

    inherit (lib) mkOption types;
    inherit (docs.lib) link';
  in {
    options.programs.niri = {
      settings = mkOption {
        type = types.nullOr settings.type;
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
          if builtins.isString cfg.config
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
    };
  };
  fake-docs = {
    fmt-date,
    fmt-time,
  }: {
    imports = [settings.module];

    options._ = let
      inherit (docs.lib) section header pkg-header module-doc fake-option pkg-link nixpkgs-link link-niri-release link-niri-commit link-stylix-opt link';

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
        builtins.concatMap (
          patch: let
            m = lib.strings.match "${lib.escapeRegex "https://github.com/YaLTeR/niri/commit/"}([0-9a-f]{40})${lib.escapeRegex ".patch"}" patch.url;
          in
            if m != null
            then [
              {
                rev = builtins.head m;
                inherit (patch) url;
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

            ${builtins.concatStringsSep "\n" (map ({
              rev,
              url,
            }: "- [`${rev}`](${lib.removeSuffix ".patch" url})")
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

  render = cfg:
    if cfg == null
    then null
    else let
      inherit (kdl) node leaf plain flag;
      optional-node = cond: v:
        if cond
        then v
        else null;

      nullable = f: name: value: optional-node (value != null) (f name value);
      flag' = name: lib.flip optional-node (flag name);
      plain' = name: children: optional-node (builtins.any (v: v != null) children) (plain name children);

      map' = node: f: name: val: node name (f val);

      toggle = disabled: cfg: contents:
        if cfg.enable
        then contents
        else flag disabled;

      toggle' = disabled: cfg: contents: [
        (flag' disabled (cfg.enable == false))
        contents
      ];

      pointer = cfg: [
        (flag' "natural-scroll" cfg.natural-scroll)
        (flag' "middle-emulation" cfg.middle-emulation)
        (leaf "accel-speed" cfg.accel-speed)
        (nullable leaf "accel-profile" cfg.accel-profile)
        (nullable leaf "scroll-button" cfg.scroll-button)
        (nullable leaf "scroll-method" cfg.scroll-method)
      ];

      pointer-tablet = cfg: inner: (toggle "off" cfg [
        (flag' "left-handed" cfg.left-handed)
        inner
      ]);

      touchy = cfg: [
        (nullable leaf "map-to-output" cfg.map-to-output)
      ];

      tablet = cfg:
        touchy cfg
        ++ [
          (nullable leaf "calibration-matrix" cfg.calibration-matrix)
        ];

      gradient' = name: cfg:
        leaf name
        (lib.concatMapAttrs (name: value:
          lib.optionalAttrs (value != null) {
            ${lib.removeSuffix "'" name} = value;
          })
        cfg);

      borderish = map' plain (cfg:
        toggle "off" cfg [
          (leaf "width" cfg.width)
          (nullable leaf "active-color" cfg.active.color or null)
          (nullable gradient' "active-gradient" cfg.active.gradient or null)
          (nullable leaf "inactive-color" cfg.inactive.color or null)
          (nullable gradient' "inactive-gradient" cfg.inactive.gradient or null)
        ]);

      shadow = map' (nullable plain) (cfg:
        optional-node (cfg.enable) [
          (flag "on")
          (leaf "offset" cfg.offset)
          (leaf "softness" cfg.softness)
          (leaf "spread" cfg.spread)

          (leaf "draw-behind-window" cfg.draw-behind-window)
          (leaf "color" cfg.color)
          (nullable leaf "inactive-color" cfg.inactive-color)
        ]);

      tab-indicator = map' plain (cfg:
        toggle "off" cfg [
          (flag' "hide-when-single-tab" cfg.hide-when-single-tab)
          (flag' "place-within-column" cfg.place-within-column)
          (leaf "gap" cfg.gap)
          (leaf "width" cfg.width)
          (leaf "length" cfg.length)
          (leaf "position" cfg.position)
          (leaf "gaps-between-tabs" cfg.gaps-between-tabs)
          (leaf "corner-radius" cfg.corner-radius)
          (nullable leaf "active-color" cfg.active.color or null)
          (nullable gradient' "active-gradient" cfg.active.gradient or null)
          (nullable leaf "inactive-color" cfg.inactive.color or null)
          (nullable gradient' "inactive-gradient" cfg.inactive.gradient or null)
        ]);

      preset-sizes = map' (nullable plain) (cfg:
        if cfg == []
        then null
        else map (lib.mapAttrsToList leaf) (lib.toList cfg));

      animation = shader:
        map' plain (cfg: [
          (flag' "off" (cfg == null))
          (optional-node (cfg ? easing) [
            (leaf "duration-ms" cfg.easing.duration-ms)
            (leaf "curve" cfg.easing.curve)
          ])
          (nullable leaf "spring" cfg.spring or null)
          (nullable leaf "custom-shader" shader)
        ]);

      animation' = shader: name: cfg: optional-node (cfg._internal_niri_flake.${name}.is-defined || shader != null) (animation shader name cfg.${name});

      opt-props = lib.filterAttrs (lib.const (value: value != null));
      border-rule = map' plain' (cfg: [
        (flag' "on" (cfg.enable == true))
        (flag' "off" (cfg.enable == false))
        (nullable leaf "width" cfg.width)
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
        (nullable leaf "active-color" cfg.active.color or null)
        (nullable gradient' "active-gradient" cfg.active.gradient or null)
        (nullable leaf "inactive-color" cfg.inactive.color or null)
        (nullable gradient' "inactive-gradient" cfg.inactive.gradient or null)
      ]);

      corner-radius = cfg: [cfg.top-left cfg.top-right cfg.bottom-right cfg.bottom-left];

      window-rule = cfg:
        plain "window-rule" [
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
        ];

      layer-rule = cfg:
        plain "layer-rule" [
          (map (leaf "match") (map opt-props cfg.matches))
          (map (leaf "exclude") (map opt-props cfg.excludes))
          (nullable leaf "opacity" cfg.opacity)
          (nullable leaf "block-out-from" cfg.block-out-from)
          (shadow-rule "shadow" cfg.shadow)
          (nullable (map' leaf corner-radius) "geometry-corner-radius" cfg.geometry-corner-radius)
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
        cfg' = builtins.mapAttrs (lib.const toString) cfg;
      in
        if cfg.refresh == null
        then "${cfg'.width}x${cfg'.height}"
        else "${cfg'.width}x${cfg'.height}@${cfg'.refresh}";

      bind = name: cfg: let
        bool-props-with-defaults = cfg: defaults:
          opt-props (builtins.mapAttrs (name: value: (
              if (defaults ? ${name}) && (value != defaults.${name})
              then value
              else null
            ))
            cfg);
      in
        node name (opt-props {
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
          }) [
          (lib.mapAttrsToList leaf cfg.action)
        ];

      switch-bind = name: cfg:
        plain name [
          (lib.mapAttrsToList leaf cfg.action)
        ];

      workspace = cfg:
        node "workspace" cfg.name [
          (nullable leaf "open-on-output" cfg.open-on-output)
        ];

      pointer-tablet' = ext: name: cfg: plain name (pointer-tablet cfg (ext cfg));
      pointer' = pointer-tablet' pointer;
      tablet' = pointer-tablet' tablet;

      gestures = map' plain (cfg: [
        (plain "dnd-edge-view-scroll" [
          (leaf "trigger-width" cfg.dnd-edge-view-scroll.trigger-width)
          (leaf "delay-ms" cfg.dnd-edge-view-scroll.delay-ms)
          (leaf "max-speed" cfg.dnd-edge-view-scroll.max-speed)
        ])
        (plain "hot-corners" [
          (flag' "off" (cfg.hot-corners.enable == false))
        ])
      ]);
    in [
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
        ])
        (plain "touchpad" (pointer-tablet cfg.input.touchpad [
          (flag' "tap" cfg.input.touchpad.tap)
          (flag' "dwt" cfg.input.touchpad.dwt)
          (flag' "dwtp" cfg.input.touchpad.dwtp)
          (flag' "drag-lock" cfg.input.touchpad.drag-lock)
          (flag' "disabled-on-external-mouse" cfg.input.touchpad.disabled-on-external-mouse)
          (pointer cfg.input.touchpad)
          (nullable leaf "click-method" cfg.input.touchpad.click-method)
          (nullable leaf "tap-button-map" cfg.input.touchpad.tap-button-map)
          (nullable leaf "scroll-factor" cfg.input.touchpad.scroll-factor)
        ]))
        (plain "mouse" (pointer-tablet cfg.input.mouse [
          (pointer cfg.input.mouse)
          (nullable leaf "scroll-factor" cfg.input.mouse.scroll-factor)
        ]))
        (pointer' "trackpoint" cfg.input.trackpoint)
        (pointer' "trackball" cfg.input.trackball)
        (tablet' "tablet" cfg.input.tablet)
        (plain "touch" (touchy cfg.input.touch))
        (flag' "warp-mouse-to-focus" cfg.input.warp-mouse-to-focus)
        (optional-node cfg.input.focus-follows-mouse.enable (leaf "focus-follows-mouse" (lib.optionalAttrs (cfg.input.focus-follows-mouse.max-scroll-amount != null) {
          inherit (cfg.input.focus-follows-mouse) max-scroll-amount;
        })))
        (flag' "workspace-auto-back-and-forth" cfg.input.workspace-auto-back-and-forth)
        (toggle "disable-power-key-handling" cfg.input.power-key-handling [])
      ])

      (lib.mapAttrsToList (name: cfg:
        node "output" name [
          (toggle' "off" cfg [
            (nullable leaf "backdrop-color" cfg.backdrop-color)
            (nullable leaf "background-color" cfg.background-color)
            (nullable leaf "scale" cfg.scale)
            (map' leaf transform "transform" cfg.transform)
            (nullable leaf "position" cfg.position)
            (nullable (map' leaf mode) "mode" cfg.mode)
            (
              optional-node (cfg.variable-refresh-rate != false)
              (leaf "variable-refresh-rate" {on-demand = cfg.variable-refresh-rate == "on-demand";})
            )
          ])
        ])
      cfg.outputs)

      (leaf "screenshot-path" cfg.screenshot-path)
      (flag' "prefer-no-csd" cfg.prefer-no-csd)

      (nullable plain "overview" (
        let
          children = lib.mapAttrsToList (nullable leaf) cfg.overview;
        in
          if lib.remove null children == []
          then null
          else children
      ))

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
        (shadow "shadow" cfg.layout.shadow)
        (nullable tab-indicator "tab-indicator" cfg.layout.tab-indicator)
        (plain "insert-hint" [
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

      (plain "hotkey-overlay" [
        (flag' "skip-at-startup" cfg.hotkey-overlay.skip-at-startup)
      ])

      (plain' "clipboard" [
        (flag' "disable-primary" cfg.clipboard.disable-primary)
      ])

      (plain "environment" (lib.mapAttrsToList leaf cfg.environment))
      (plain "binds" (lib.mapAttrsToList bind cfg.binds))
      (nullable plain "switch-events" (
        let
          children = lib.mapAttrsToList (nullable switch-bind) cfg.switch-events;
        in
          if lib.remove null children == []
          then null
          else children
      ))

      (map workspace (builtins.sort (a: b: a.sort-name < b.sort-name)
        (lib.mapAttrsToList (key: cfg:
          cfg
          // {
            sort-name = key;
            name =
              if cfg.name != null
              then cfg.name
              else key;
          })
        cfg.workspaces)))

      (map (map' leaf (builtins.getAttr "command") "spawn-at-startup") cfg.spawn-at-startup)
      (map window-rule cfg.window-rules)
      (map layer-rule cfg.layer-rules)

      (nullable gestures "gestures" cfg.gestures)

      (plain "animations" [
        (toggle "off" cfg.animations [
          (leaf "slowdown" cfg.animations.slowdown)
          (animation' null "workspace-switch" cfg.animations)
          (animation' null "horizontal-view-movement" cfg.animations)
          (animation' null "config-notification-open-close" cfg.animations)
          (animation' null "window-movement" cfg.animations)
          (animation' cfg.animations.shaders.window-open "window-open" cfg.animations)
          (animation' cfg.animations.shaders.window-close "window-close" cfg.animations)
          (animation' cfg.animations.shaders.window-resize "window-resize" cfg.animations)
          (animation' null "screenshot-ui-open" cfg.animations)
        ])
      ])

      (nullable (map' plain (lib.mapAttrsToList leaf)) "debug" cfg.debug)
    ];
}
