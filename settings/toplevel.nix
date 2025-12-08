{
  lib,
  config,
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
    make-ordered-options
    ;
in

let
  files =
    map
      (
        f:
        import f {
          inherit
            lib
            kdl
            fragments
            niri-flake-internal
            toplevel-options
            ;
        }
      )
      [
        ./input.nix
        ./outputs.nix
        ./binds.nix
        ./switch-events.nix
        ./layout.nix
        ./overview.nix

        ./workspaces.nix

        ./misc.nix

        ./surface-rules.nix
        ./animations.nix
        ./gestures.nix

        ./debug.nix
      ];

  fragments = lib.mergeAttrsList (builtins.map (f: f.fragments or { }) files);

  sections = builtins.concatMap (f: f.sections or [ ]) files;

  render-utils = rec {
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
  };
in
{
  imports = (make-ordered-options (map (s: s.options) sections));
  options.rendered = lib.mkOption {
    type = kdl.types.kdl-document;
    readOnly = true;
  };
  config.rendered =
    let
      cfg = config;
      inherit (render-utils)
        normalize-nodes
        plain
        nullable
        leaf
        flag'
        plain'
        pointer-tablet
        pointer
        pointer'
        tablet'
        touch
        optional-node
        toggle
        each'
        node
        map'
        borderish
        shadow
        tab-indicator
        gradient'
        preset-sizes
        bind
        each
        opt-props
        corner-radius
        border-rule
        shadow-rule
        tab-indicator-rule
        ;
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

      (plain' "xwayland-satellite" [
        (toggle "off" cfg.xwayland-satellite [
          (nullable leaf "path" cfg.xwayland-satellite.path)
        ])
      ])

      (map' plain' (lib.mapAttrsToList leaf) "debug" cfg.debug)

    ]
    ++ map (s: (s.render or (_: [ ])) config) sections;
}
