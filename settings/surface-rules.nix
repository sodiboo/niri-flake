{
  lib,
  kdl,
  niri-flake-internal,
  toplevel-options,
}:

let
  inherit (lib) types;
  inherit (lib.types) enum;
  inherit (niri-flake-internal)
    fmt
    link-opt
    subopts
    section
    section'
    make-decoration-options
    make-ordered-options
    nullable
    float-or-int
    record
    required
    ordered-record'
    shadow-descriptions
    regex
    list
    default-width
    default-height
    ;

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

in
{
  sections = [
    {
      options.window-rules =
        let
          window-rule-descriptions = rule-descriptions {
            surface = "window";
            surfaces = "windows";
            surface-rule = "window rule";
            Surface-rules = "Window rules";

            self = toplevel-options.window-rules;
            spawn-at-startup = toplevel-options.spawn-at-startup;

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

                  If any of these rules match a window (or there are none), that window rule will be considered for this window. It can still be rejected by ${link-opt (subopts toplevel-options.window-rules).excludes}

                  If all of the rules do not match a window, then this window rule will not apply to that window.
                '';
              };
            }
            {
              excludes = list window-match // {
                description = ''
                  A list of rules to exclude windows.

                  If any of these rules match a window, then this window rule will not apply to that window, even if it matches one of the rules in ${link-opt (subopts toplevel-options.window-rules).matches}

                  If none of these rules match a window, then this window rule will not be rejected. It will apply to that window if and only if it matches one of the rules in ${link-opt (subopts toplevel-options.window-rules).matches}
                '';
              };
            }
            {
              default-column-width = nullable default-width // {
                description = ''
                  The default width for new columns.

                  If the final value of this option is null, it default to ${link-opt (subopts toplevel-options.layout).default-column-width}

                  If the final value option is not null, then its value will take priority over ${link-opt (subopts toplevel-options.layout).default-column-width} for windows matching this rule.

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

                    If the final value of this field is null, then the default display mode is taken from ${link-opt (subopts toplevel-options.layout).default-column-display}.
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

                  Set ${link-opt (subopts toplevel-options.window-rules).clip-to-geometry} to true to clip the window to its visual geometry, i.e. apply the corner radius to the window surface itself.
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
                  See ${link-opt (subopts toplevel-options.layout).border}.
                '';
              };
              focus-ring = border-rule {
                name = "focus ring";
                window = "matched window with focus";
                description = ''
                  See ${link-opt (subopts toplevel-options.layout).focus-ring}.
                '';
              };

              tab-indicator =
                let
                  layout-tab-indicator = subopts (subopts toplevel-options.layout).tab-indicator;
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
                  Takes effect only when the window is on an output with ${link-opt (subopts toplevel-options.outputs).variable-refresh-rate} set to ${fmt.code ''"on-demand"''}. If the final value of this field is true, then the output will enable variable refresh rate when this window is present on it.
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
      options.layer-rules =
        let
          layer-rule-descriptions = rule-descriptions {
            surface = "layer surface";
            surfaces = "layer surfaces";
            surface-rule = "layer rule";
            Surface-rules = "Layer rules";

            self = toplevel-options.layer-rules;
            spawn-at-startup = toplevel-options.spawn-at-startup;

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
  ];
}
