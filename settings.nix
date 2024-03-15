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
        mkOption {
          type = mkOptionType {
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
          };
          description = "animations";
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
  }: {
    imports = [module];

    options._ = let
      section = contents:
        mkOption {
          type = mkOptionType {name = "docs-override";};
          description = contents;
        };

      header = title: section "# ${title}";
      fake-option = loc: contents:
        section ''
          ## `${loc}`

          ${contents}
        '';

      test = pat: str: strings.match pat str != null;

      anchor = flip pipe [
        (replaceStrings (upperChars ++ [" "]) (lowerChars ++ ["-"]))
        (splitString "")
        (filter (test "[a-z0-9-]"))
        concatStrings
      ];

      link = title: "[${title}](#${anchor title})";
      link' = loc: link "`${loc}`";

      opt-mod = module: "Options for `${module}`";
      link-opts = module: link (opt-mod module);

      stylix-note = ''
        Note that enabling the stylix target will cause a config file to be generated, even if you don't set ${link' "programs.niri.config"}.
      '';

      module = name: desc:
        fake-option name ''
          ${desc}

          see also: ${link-opts name}
        '';

      pkg-header = name: "packages.<system>.${name}";
      pkg-link = name: link' (pkg-header name);

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
        - default: `pkgs.niri-stable`

        The package that niri will use.

        By default, this is niri-stable as provided by my flake. You may wish to set it to the following values:

        - [`nixpkgs.niri`](https://search.nixos.org/packages?channel=unstable&show=niri)
        - ${pkg-link "niri-stable"}
        - ${pkg-link "niri-unstable"}
      '';
      link-niri-release = tag: "[release `${tag}`](https://github.com/YaLTeR/niri/releases/tag/${tag})";
    in {
      a.outputs = {
        _ = header "Outputs provided by this flake";

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
          nixpkgs.overlays = [ niri.overlay ];
          ```

          You can then access the packages via `pkgs.niri-stable` and `pkgs.niri-unstable` as if they were part of nixpkgs.
        '';

        c.modules = {
          a.nixos = module "nixosModules.niri" ''
            The full NixOS module for niri.

            By default, this module does the following:

            - It will enable a binary cache managed by me, sodiboo. This helps you avoid building niri from source, which can take a long time in release mode.
            - If you have home-manager installed in your NixOS configuration (rather than as a standalone program), this module will automatically import ${link' "homeModules.config"} for all users and give it the correct package to use for validation.
            - If you have home-manager and stylix installed in your NixOS configuration, this module will also automatically import ${link' "homeModules.stylix"} for all users.
          '';

          b.home = module "homeModules.niri" ''
            The full home-manager module for niri.

            By default, this module does nothing. It will import ${link' "homeModules.config"}, which provides many configuration options, and it also provides some options to install niri.
          '';

          c.config = module "homeModules.config" ''
            Configuration options for niri. This module is automatically imported by ${link' "nixosModules.niri"} and ${link' "homeModules.niri"}.

            By default, this module does nothing. It provides many configuration options for niri, such as keybindings, animations, and window rules.

            When its options are set, it generates `$XDGN_CONFIG_HOME/niri/config.kdl` for the user. This is the default path for niri's config file.

            It will also validate the config file with the `niri validate` command before committing that config. This ensures that the config file is always valid, else your system will fail to build. When using ${link' "programs.niri.settings"} to configure niri, that's not necessary, because it will always generate a valid config file. But, if you set ${link' "programs.niri.config"} directly, then this is very useful.
          '';

          d.stylix = module "homeModules.stylix" ''
            Stylix integration. It provides a target to enable niri.

            This module is automatically imported if you have home-manager and stylix installed in your NixOS configuration.

            If you use standalone home-manager, you must import it manually if you wish to use stylix with niri. (since it can't be automatically imported in that case)

            ${stylix-note}
          '';
        };
      };

      b.nixos = {
        _ = header (opt-mod "nixosModules.niri");
        enable = enable-option;
        package = package-option;
        z.cache = fake-option "niri-flake.cache.enable" ''
          - type: `boolean`
          - default: `true`

          Whether or not to enable the binary cache managed by me, sodiboo.

          This is enabled by default, because there's not much reason to *not* use it. But, if you wish to disable it, you may.
        '';
      };

      c.home = {
        _ = header (opt-mod "homeModules.niri");
        enable = enable-option;
        package = package-option;
      };

      d.stylix = {
        _ = header (opt-mod "homeModules.stylix");
        target = fake-option "stylix.targets.niri.enable" ''
          - type: `boolean`
          - default: `stylix.autoEnable`

          Whether to style niri according to your stylix config.
        '';
      };

      z.pre-config = {
        _ = header (opt-mod "homeModules.config");
        package = fake-option "programs.niri.package" ''
          - type: `package`
          - default: `pkgs.niri-stable`

          The `niri` package that the config is validated against. This cannot be modified if you set the identically-named option in ${link' "nixosModules.niri"} or ${link' "homeModules.niri"}.
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
