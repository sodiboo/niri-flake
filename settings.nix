{
  kdl,
  lib,
}:
with lib; let
  module = let
    inherit (types) nullOr attrsOf listOf submodule enum either;

    record = options: submodule {inherit options;};

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
          (record (mapAttrs (const required)
              variants))
          .getSubOptions;
      };

    basic-pointer = default-natural-scroll: {
      natural-scroll = optional types.bool default-natural-scroll;
      accel-speed = optional types.float 0.0;
      accel-profile = nullable (enum ["adaptive" "flat"]);
    };

    preset-width = variant {
      fixed = types.int;
      proportion = types.float;
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
    animation = nullOr (variant {
      spring = record {
        damping-ratio = required types.float;
        stiffness = required types.int;
        epsilon = required types.float;
      };
      easing = record {
        duration-ms = required types.int;
        curve = required (enum ["ease-out-cubic" "ease-out-expo"]);
      };
    });

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

    settings = record {
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
        workspace-switch = optional animation {
          spring = {
            damping-ratio = 1.0;
            stiffness = 1000;
            epsilon = 0.0001;
          };
        };
        horizontal-view-movement = optional animation {
          spring = {
            damping-ratio = 1.0;
            stiffness = 800;
            epsilon = 0.0001;
          };
        };
        config-notification-open-close = optional animation {
          spring = {
            damping-ratio = 0.6;
            stiffness = 1000;
            epsilon = 0.001;
          };
        };
        window-open = optional animation {
          easing = {
            duration-ms = 150;
            curve = "ease-out-expo";
          };
        };
      };

      environment = attrs (nullOr (types.str));

      binds = attrs (either types.str kdl.types.kdl-leaf);

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

      debug = nullable (attrsOf kdl.types.kdl-args);
    };
  in
    {config, ...}: let
      cfg = config.programs.niri;
    in {
      options.programs.niri = {
        config = mkOption {
          type = types.nullOr (types.either types.str kdl.types.kdl-document);
          default = render cfg.settings;
          defaultText = "<dependent on programs.niri.settings>";
          description = ''
            The niri config file.

            - When this is null, no config file is generated.
            - When this is a string, it is assumed to be the config file contents.
            - When this is kdl document, it is serialized to a string before being used as the config file contents.

            By default, this is a KDL document that reflects the settings in `programs.niri.settings`.
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

          defaultText = "<dependent on programs.niri.config>";

          description = ''
            The final niri config file contents.

            This is a string that reflects the document stored in `programs.niri.config`.

            It is exposed mainly for debugging purposes, such as when you need to inspect how a certain option affects the resulting config file.
          '';
        };

        settings =
          (nullable settings)
          // {
            description = ''
              Nix-native settings for niri.

              By default, when this is null, no config file is generated.

              Beware that setting `programs.niri.config` completely overrides everything under this option.
            '';
          };
      };
    };
  fake-docs = {
    stable-tag,
    nixpkgs,
  }: let
    section = contents:
      mkOption {
        type = mkOptionType {name = "docs-override";};
        description = contents;
      };
    fake-option = loc: contents:
      section ''
        ## `${loc}`

        ${contents}
      '';
  in {
    imports = [module];

    options._ = {
      a.outputs = {
      };
      b.nixos = {
        _ = section ''
          # Options available in the NixOS module
        '';
        enable = fake-option "programs.niri.enable" ''
          - type: `boolean`
          - default: `false`

          Whether to install and enable niri.

          This also enables the necessary system components for niri to function properly, such as desktop portals and polkit.
        '';

        package = fake-option "programs.niri.package" ''
          - type: `package`
          - default: `pkgs.niri-stable`

          The package that niri will use.

          By default, this is niri-stable as provided by my flake. You may wish to set it to the following values:

          - `pkgs.niri` (niri v${nixpkgs.legacyPackages.x86_64-linux.niri.version}; from nixpkgs)
          - `pkgs.niri-stable` (niri ${stable-tag}; from niri-flake)
          - `pkgs.niri-unstable` (latest commit; from niri-flake)

          Note that the packages provided by this flake are available only if you add the overlay.
        '';

        z.cache = fake-option "niri-flake.cache.enable" ''
          - type: `boolean`
          - default: `true`

          Whether or not to enable the binary cache managed by me, sodiboo.

          This is enabled by default, because there's not much reason to *not* use it. But, if you wish to disable it, you may.
        '';
      };

      z.pre-config = {
        _ = section ''
          # Options available in the home-manager module
        '';
        variant = section ''
          ## type: `variant of`

          Some of the options below make use of a "variant" type.

          This is a type that behaves similarly to a submodule, except you can only set *one* of its suboptions.

          An example of this usage is in animations, where each action can have either an easing animation or a spring animation. \
          You cannot set parameters for both, so `variant` is used here.
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
              (nullable leaf "layout" cfg.input.keyboard.xkb.layout)
              (nullable leaf "model" cfg.input.keyboard.xkb.model)
              (nullable leaf "rules" cfg.input.keyboard.xkb.rules)
              (nullable leaf "variant" cfg.input.keyboard.xkb.variant)
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
in {
  inherit module render fake-docs;
}
