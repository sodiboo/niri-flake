{kdl}: {
  lib,
  config,
  ...
}:
with kdl;
with lib; {
  options.programs.niri.settings = let
    inherit (types) nullOr attrsOf listOf submodule enum;

    record = options: submodule {inherit options;};

    required = type: mkOption {inherit type;};
    nullable = type: optional (nullOr type) null;
    optional = type: default: mkOption {inherit type default;};

    attrs = type: optional (attrsOf type) {};
    list = type: optional (listOf type) [];

    basic-pointer = default-natural-scroll: {
      natural-scroll = optional types.bool default-natural-scroll;
      accel-speed = optional types.float 0.0;
      accel-profile = nullable (enum ["adaptive" "flat"]);
    };

    preset-width = mkOptionType {
      name = "preset-width";
      description = "width (fixed pixels or proportion of the screen)";
      descriptionClass = "noun";
      check = v: let
        names = attrNames v;
        is-proportion = head names == "proportion" && isFloat v.proportion;
        is-fixed = head names == "fixed" && isInt v.fixed;
      in
        isAttrs v && (length names == 1) && (is-proportion || is-fixed);
    };

    default-width = types.either preset-width (enum [{}]);

    # niri seems to have deprecated this way of defining colors; so we won't support it
    # color-array = mkOptionType {
    #   name = "color";
    #   description = "[red green blue alpha]";
    #   descriptionClass = "noun";
    #   check = v: isList v && length v == 4 && all isInt v;
    # };

    animation = {
      duration ? 250,
      curve ? "ease-out-cubic",
    }: {
      enable = optional types.bool true;
      duration-ms = optional (nullOr types.int) duration;
      animation-curve = optional (nullOr (enum ["ease-out-cubic" "ease-out-expo"])) curve;
    };

    gradient = record {
      from = required types.str;
      to = required types.str;
      angle = optional types.int 180;
      relative-to = optional (enum ["window" "workspace-view"]) "window";
    };

    borderish = default-active-color: {
      enable = optional types.bool enable;
      width = optional types.int 4;
      active-color = optional types.str default-active-color;
      inactive-color = optional types.str "rgb(80 80 80)";
      active-gradient = nullable gradient;
      inactive-gradient = nullable gradient;
    };

    bind = mkOptionType {
      name = "bind";
      description = "key binding";
      descriptionClass = "noun";
      check = v: let
        leaves = mapAttrsToList kdl.leaf v;
      in
        isString v || (isAttrs v && length leaves == 1 && all kdl.types.kdl-node.check leaves);
    };

    # why not just use a record? because, it is slightly more convenient to use
    # if inactive fields are missing rather than null
    match = mkOptionType {
      name = "match";
      description = "match rule";
      descriptionClass = "noun";
      check = v: isAttrs v && all (flip elem ["app-id" "title"]) (attrNames v) && all isString (attrValues v);
    };
  in {
    input = {
      keyboard = {
        xkb = {
          layout = nullable types.str;
          model = nullable types.str;
          rules = nullable types.str;
          variant = nullable types.str;
          options = nullable types.str;
        };
        repeat-delay = optional types.int 600;
        repeat-rate = optional types.int 25;
        track-layout = optional (enum ["global" "window"]) "global";
      };
      touchpad =
        (basic-pointer true)
        // {
          tap = optional types.bool true;
          dwt = optional types.bool false;
          dwtp = optional types.bool false;
          tap-button-map = nullable (enum ["left-middle-right" "left-right-middle"]);
        };
      mouse = basic-pointer false;
      trackpoint = basic-pointer false;
      tablet.map-to-output = nullable types.str;
      touch.map-to-output = nullable types.str;

      power-key-handling.enable = optional types.bool true;
    };

    outputs = attrs (record {
      enable = optional types.bool true;
      scale = optional types.float 1.0;
      transform = {
        flipped = optional types.bool false;
        rotation = optional (enum [0 90 180 270]) 0;
      };
      position = nullable (record {
        x = required types.int;
        y = required types.int;
      });
      mode = nullable (record {
        width = required types.int;
        height = required types.int;
        refresh = nullable types.float;
      });
    });

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
      preset-column-widths = list preset-width;
      default-column-width = optional default-width {};
      center-focused-column = optional (enum ["never" "always" "on-overflow"]) "never";
      gaps = optional types.int 16;
      struts = {
        left = optional types.int 0;
        right = optional types.int 0;
        top = optional types.int 0;
        bottom = optional types.int 0;
      };
    };

    prefer-no-csd = optional types.bool false;

    cursor = {
      theme = optional types.str "default";
      size = optional types.int 24;
    };

    screenshot-path = optional (nullOr types.str) "~/Pictures/Screenshots/Screenshot from %Y-%m-%d %H-%M-%S.png";

    hotkey-overlay.skip-at-startup = optional types.bool false;

    animations = {
      enable = optional types.bool true;
      slowdown = optional types.float 1.0;
      workspace-switch = animation {};
      horizontal-view-movement = animation {};
      window-open = animation {
        duration = 150;
        curve = "ease-out-expo";
      };
      config-notification-open-close = animation {};
    };

    environment = attrs (nullOr (types.str));

    binds = attrs bind;

    spawn-at-startup = list (record {
      command = list types.str;
    });

    window-rules = list (record {
      matches = list match;
      excludes = list match;

      default-column-width = nullable default-width;
      open-on-output = nullable types.str;
      open-maximized = nullable types.bool;
      open-fullscreen = nullable types.bool;
    });

    additional-nodes = optional kdl.types.kdl-nodes [];
  };

  options.programs.niri.generated-kdl-config = let
    cfg = config.programs.niri.settings;
    nullable = f: name: value: 
      if value == null
      then null
      else f name value;

    map' = node: f: name: val: node name (f val);

    plain-leaf' = name: cond:
      if cond
      then (plain-leaf name)
      else null;

    toggle = disabled: cfg: contents:
      if cfg.enable
      then contents
      else plain-leaf disabled;
    
    named = kind: set: name: kind name set.${name}; 

    pointer = cfg: [
      (plain-leaf' "natural-scroll" cfg.natural-scroll)
      (leaf "accel-speed" cfg.accel-speed)
      (nullable leaf "accel-profile" cfg.accel-profile)
    ];

    touchy = map' plain (mapAttrsToList leaf);

    borderish = name: cfg:
      plain name [
        (toggle "off" cfg
          # width and (in)?active-color are not nullable
          # but that doesn't matter
          (map (named (nullable leaf) cfg) ["width" "active-color" "inactive-color" "active-gradient" "inactive-gradient"]))
      ];

    # preset-widths = name: cfg: plain name (map (mapAttrsToList leaf) (toList cfg));
    preset-widths = map' plain (cfg: map (mapAttrsToList leaf) (toList cfg));
  in
    mkOption {
      type = kdl.types.kdl-nodes;
      readOnly = true;
      default = with kdl; [
        (plain "input" [
          (plain "keyboard" [
            (plain "xkb" [
              (map (named (nullable leaf) cfg.input.keyboard.xkb) [
                "layout"
                "model"
                "rules"
                "variant"
                "options"
              ])
            ])
            (map (named leaf cfg.input.keyboard) [
              "repeat-delay"
              "repeat-rate"
              "track-layout"
            ])
          ])
          (plain "touchpad" [
            (map (named plain-leaf' cfg.input.touchpad) ["tap" "dwt" "dwtp"])
            (pointer cfg.input.touchpad)
            (nullable leaf "tap-button-map" cfg.input.touchpad.tap-button-map)
          ])
          (map (named (map' plain pointer) cfg.input) ["mouse" "trackpoint"])
          (map (named touchy cfg.input) ["tablet" "touch"])
          (toggle "disable-power-key-handling" cfg.input.power-key-handling [])
        ])

        (mapAttrsToList (name: cfg:
          node "output" name [
            (toggle "off" cfg [
              (leaf "scale" cfg.scale)
              (leaf "transform" (let
                rotation = toString cfg.transform.rotation;
                basic =
                  if cfg.transform.flipped
                  then "flipped-${rotation}"
                  else "${rotation}";
                replacement."0" = "normal";
                replacement."flipped-0" = "flipped";
              in
                replacement.${basic} or basic))
              (nullable leaf "position" cfg.position)
              (nullable (map' leaf (cfg: let
                geometry = "${cfg.width}x${cfg.height}";
                mode =
                  if cfg.refresh == null
                  then "${geometry}"
                  else "${geometry}@${cfg.refresh}";
              in
                mode)) "mode" cfg.mode)
            ])
          ])
        cfg.outputs)

        (plain-leaf' "prefer-no-csd" cfg.prefer-no-csd)

        (plain "layout" [
          (leaf "gaps" cfg.layout.gaps)
          (plain "struts" [
            (map (named leaf cfg.layout.struts) ["left" "right" "top" "bottom"])
          ])
          (borderish "focus-ring" cfg.layout.focus-ring)
          (borderish "border" cfg.layout.border)
          (preset-widths "preset-column-widths" cfg.layout.preset-column-widths)
          (preset-widths "default-column-width" cfg.layout.default-column-width)
        ])

        (plain "cursor" [
          (leaf "xcursor-theme" cfg.cursor.theme)
          (leaf "xcursor-size" cfg.cursor.size)
        ])

        (plain "hotkey-overlay" [
          (plain-leaf' "skip-at-startup" cfg.hotkey-overlay.skip-at-startup)
        ])

        (plain "environment" (mapAttrsToList leaf cfg.environment))
        (plain "binds" (mapAttrsToList (name: bind:
          plain name [
            (
              if isString bind
              then plain-leaf bind
              else mapAttrsToList leaf bind
            )
          ])
        cfg.binds))

        (map (cfg: leaf "spawn-at-startup" cfg.command) cfg.spawn-at-startup)
        (map (cfg:
          plain "window-rule" [
            (map (named (name: map (leaf name)) cfg) ["matches" "excludes"])
            (nullable preset-widths "default-column-width" cfg.default-column-width)
            (map (named (nullable leaf) cfg) ["open-on-output" "open-maximized" "open-fullscreen"])
          ])
        cfg.window-rules)

        cfg.additional-nodes
      ];
    };
}
