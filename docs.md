# Outputs provided by this flake

## `nixosModules.niri`

The full NixOS module for niri.

By default, this module does the following:

- It will enable a binary cache managed by me, sodiboo. This helps you avoid building niri from source, which can take a long time in release mode.
- If you have home-manager installed in your NixOS configuration (rather than as a standalone program), this module will automatically import [`homeModules.config`](#homemodulesconfig) for all users and give it the correct package to use for validation.
- If you have home-manager and stylix installed in your NixOS configuration, this module will also automatically import [`homeModules.stylix`](#homemodulesstylix) for all users.


see also: [Options for `nixosModules.niri`](#options-for-nixosmodulesniri)



## `homeModules.niri`

The full home-manager module for niri.

By default, this module does nothing. It will import [`homeModules.config`](#homemodulesconfig), which provides many configuration options, and it also provides some options to install niri.


see also: [Options for `homeModules.niri`](#options-for-homemodulesniri)



## `homeModules.config`

Configuration options for niri. This module is automatically imported by [`nixosModules.niri`](#nixosmodulesniri) and [`homeModules.niri`](#homemodulesniri).

By default, this module does nothing. It provides many configuration options for niri, such as keybindings, animations, and window rules.

When its options are set, it generates `$XDGN_CONFIG_HOME/niri/config.kdl` for the user. This is the default path for niri's config file.

It will also validate the config file with the `niri validate` command before committing that config. This ensures that the config file is always valid, else your system will fail to build. When using [`programs.niri.settings`](#programsnirisettings) to configure niri, that's not necessary, because it will always generate a valid config file. But, if you set [`programs.niri.config`](#programsniriconfig) directly, then this is very useful.


see also: [Options for `homeModules.config`](#options-for-homemodulesconfig)



## `homeModules.stylix`

Stylix integration. It provides a target to enable niri.

This module is automatically imported if you have home-manager and stylix installed in your NixOS configuration.

If you use standalone home-manager, you must import it manually if you wish to use stylix with niri. (since it can't be automatically imported in that case)

Note that enabling the stylix target will cause a config file to be generated, even if you don't set [`programs.niri.config`](#programsniriconfig).



see also: [Options for `homeModules.stylix`](#options-for-homemodulesstylix)



## `packages.<system>.niri-stable`

(where `<system>` is one of: `x86_64-linux`, `aarch64-linux`)

The latest stable tagged version of niri (currently [release `v0.1.3`](https://github.com/YaLTeR/niri/releases/tag/v0.1.3)), along with potential patches.


Note that the `aarch64-linux` package is untested. It might work, but i can't guarantee it.

Also note that you likely should not be using these outputs directly. Instead, you should use the overlay ([`overlays.niri`](#overlaysniri)).



## `packages.<system>.niri-unstable`

(where `<system>` is one of: `x86_64-linux`, `aarch64-linux`)

The latest commit to the main branch of niri. This is refreshed hourly and may break at any time without prior notice.


Note that the `aarch64-linux` package is untested. It might work, but i can't guarantee it.

Also note that you likely should not be using these outputs directly. Instead, you should use the overlay ([`overlays.niri`](#overlaysniri)).



## `overlays.niri`

A nixpkgs overlay that provides `niri-stable` and `niri-unstable`.

It is recommended to use this overlay over directly accessing the outputs. This is because the overlay ensures that the dependencies match your system's nixpkgs version, which is most important for `mesa`. If `mesa` doesn't match, niri will be unable to run in a TTY.

You can enable this overlay by adding this line to your configuration:

```nix
nixpkgs.overlays = [ niri.overlay ];
```

You can then access the packages via `pkgs.niri-stable` and `pkgs.niri-unstable` as if they were part of nixpkgs.



# Options for `nixosModules.niri`

## `programs.niri.enable`

- type: `boolean`
- default: `false`

Whether to install and enable niri.

This also enables the necessary system components for niri to function properly, such as desktop portals and polkit.



## `programs.niri.package`

- type: `package`
- default: `pkgs.niri-stable`

The package that niri will use.

By default, this is niri-stable as provided by my flake. You may wish to set it to the following values:

- [`nixpkgs.niri`](https://search.nixos.org/packages?channel=unstable&show=niri)
- [`packages.<system>.niri-stable`](#packagessystemniri-stable)
- [`packages.<system>.niri-unstable`](#packagessystemniri-unstable)



## `niri-flake.cache.enable`

- type: `boolean`
- default: `true`

Whether or not to enable the binary cache managed by me, sodiboo.

This is enabled by default, because there's not much reason to *not* use it. But, if you wish to disable it, you may.



# Options for `homeModules.niri`

## `programs.niri.enable`

- type: `boolean`
- default: `false`

Whether to install and enable niri.

This also enables the necessary system components for niri to function properly, such as desktop portals and polkit.



## `programs.niri.package`

- type: `package`
- default: `pkgs.niri-stable`

The package that niri will use.

By default, this is niri-stable as provided by my flake. You may wish to set it to the following values:

- [`nixpkgs.niri`](https://search.nixos.org/packages?channel=unstable&show=niri)
- [`packages.<system>.niri-stable`](#packagessystemniri-stable)
- [`packages.<system>.niri-unstable`](#packagessystemniri-unstable)



# Options for `homeModules.stylix`

## `stylix.targets.niri.enable`

- type: `boolean`
- default: `stylix.autoEnable`

Whether to style niri according to your stylix config.



# Options for `homeModules.config`

## `programs.niri.package`

- type: `package`
- default: `pkgs.niri-stable`

The `niri` package that the config is validated against. This cannot be modified if you set the identically-named option in [`nixosModules.niri`](#nixosmodulesniri) or [`homeModules.niri`](#homemodulesniri).



## type: `variant of`

Some of the options below make use of a "variant" type.

This is a type that behaves similarly to a submodule, except you can only set *one* of its suboptions.

An example of this usage is in animations, where each action can have either an easing animation or a spring animation. \
You cannot set parameters for both, so `variant` is used here.


## `programs.niri.config`
- type: `null or string or kdl document`
- default: `<dependent on programs.niri.settings>`

The niri config file.

- When this is null, no config file is generated.
- When this is a string, it is assumed to be the config file contents.
- When this is kdl document, it is serialized to a string before being used as the config file contents.

By default, this is a KDL document that reflects the settings in `programs.niri.settings`.


## `programs.niri.finalConfig`
- type: `null or string`
- default: `<dependent on programs.niri.config>`

The final niri config file contents.

This is a string that reflects the document stored in `programs.niri.config`.

It is exposed mainly for debugging purposes, such as when you need to inspect how a certain option affects the resulting config file.


## `programs.niri.settings`
- type: `null or (submodule)`
- default: `null`

Nix-native settings for niri.

By default, when this is null, no config file is generated.

Beware that setting `programs.niri.config` completely overrides everything under this option.


## `programs.niri.settings.animations.enable`
- type: `boolean`
- default: `true`


## `programs.niri.settings.animations.slowdown`
- type: `floating point number`
- default: `1.000000`


## `programs.niri.settings.animations.<name>`
- type: `animation`, which is a `variant of: easing | spring`


## `programs.niri.settings.animations.<name>.easing.curve`
- type: `one of "ease-out-cubic", "ease-out-expo"`


## `programs.niri.settings.animations.<name>.easing.duration-ms`
- type: `signed integer`


## `programs.niri.settings.animations.<name>.spring.damping-ratio`
- type: `floating point number`


## `programs.niri.settings.animations.<name>.spring.epsilon`
- type: `floating point number`


## `programs.niri.settings.animations.<name>.spring.stiffness`
- type: `signed integer`


## `programs.niri.settings.animations.config-notification-open-close`
- type: `null or animation`
- default:
  ```nix
  {
    spring = {
      damping-ratio = 0.600000;
      epsilon = 0.001000;
      stiffness = 1000;
    };
  }
  ```



## `programs.niri.settings.animations.horizontal-view-movement`
- type: `null or animation`
- default:
  ```nix
  {
    spring = {
      damping-ratio = 1.000000;
      epsilon = 0.000100;
      stiffness = 800;
    };
  }
  ```



## `programs.niri.settings.animations.window-open`
- type: `null or animation`
- default:
  ```nix
  {
    easing = {
      curve = "ease-out-expo";
      duration-ms = 150;
    };
  }
  ```



## `programs.niri.settings.animations.workspace-switch`
- type: `null or animation`
- default:
  ```nix
  {
    spring = {
      damping-ratio = 1.000000;
      epsilon = 0.000100;
      stiffness = 1000;
    };
  }
  ```



## `programs.niri.settings.binds`
- type: `attribute set of (string or kdl leaf)`


## `programs.niri.settings.cursor.size`
- type: `signed integer`
- default: `24`


## `programs.niri.settings.cursor.theme`
- type: `string`
- default: `"default"`


## `programs.niri.settings.debug`
- type: `null or (attribute set of kdl arguments)`
- default: `null`


## `programs.niri.settings.environment`
- type: `attribute set of (null or string)`


## `programs.niri.settings.hotkey-overlay.skip-at-startup`
- type: `boolean`
- default: `false`


## `programs.niri.settings.input.keyboard.repeat-delay`
- type: `signed integer`
- default: `600`


## `programs.niri.settings.input.keyboard.repeat-rate`
- type: `signed integer`
- default: `25`


## `programs.niri.settings.input.keyboard.track-layout`
- type: `one of "global", "window"`
- default: `"global"`


## `programs.niri.settings.input.keyboard.xkb.layout`
- type: `null or string`
- default: `null`


## `programs.niri.settings.input.keyboard.xkb.model`
- type: `null or string`
- default: `null`


## `programs.niri.settings.input.keyboard.xkb.options`
- type: `null or string`
- default: `null`


## `programs.niri.settings.input.keyboard.xkb.rules`
- type: `null or string`
- default: `null`


## `programs.niri.settings.input.keyboard.xkb.variant`
- type: `null or string`
- default: `null`


## `programs.niri.settings.input.mouse.accel-profile`
- type: `null or one of "adaptive", "flat"`
- default: `null`


## `programs.niri.settings.input.mouse.accel-speed`
- type: `floating point number`
- default: `0.000000`


## `programs.niri.settings.input.mouse.natural-scroll`
- type: `boolean`
- default: `false`


## `programs.niri.settings.input.power-key-handling.enable`
- type: `boolean`
- default: `true`


## `programs.niri.settings.input.tablet.map-to-output`
- type: `null or string`
- default: `null`


## `programs.niri.settings.input.touch.map-to-output`
- type: `null or string`
- default: `null`


## `programs.niri.settings.input.touchpad.accel-profile`
- type: `null or one of "adaptive", "flat"`
- default: `null`


## `programs.niri.settings.input.touchpad.accel-speed`
- type: `floating point number`
- default: `0.000000`


## `programs.niri.settings.input.touchpad.dwt`
- type: `boolean`
- default: `false`


## `programs.niri.settings.input.touchpad.dwtp`
- type: `boolean`
- default: `false`


## `programs.niri.settings.input.touchpad.natural-scroll`
- type: `boolean`
- default: `true`


## `programs.niri.settings.input.touchpad.tap`
- type: `boolean`
- default: `true`


## `programs.niri.settings.input.touchpad.tap-button-map`
- type: `null or one of "left-middle-right", "left-right-middle"`
- default: `null`


## `programs.niri.settings.input.trackpoint.accel-profile`
- type: `null or one of "adaptive", "flat"`
- default: `null`


## `programs.niri.settings.input.trackpoint.accel-speed`
- type: `floating point number`
- default: `0.000000`


## `programs.niri.settings.input.trackpoint.natural-scroll`
- type: `boolean`
- default: `false`


## `programs.niri.settings.layout.border.active-color`
- type: `string`
- default: `"rgb(255 200 127)"`


## `programs.niri.settings.layout.border.active-gradient`
- type: `null or (submodule)`
- default: `null`


## `programs.niri.settings.layout.border.active-gradient.angle`
- type: `signed integer`
- default: `180`


## `programs.niri.settings.layout.border.active-gradient.from`
- type: `string`


## `programs.niri.settings.layout.border.active-gradient.relative-to`
- type: `one of "window", "workspace-view"`
- default: `"window"`


## `programs.niri.settings.layout.border.active-gradient.to`
- type: `string`


## `programs.niri.settings.layout.border.enable`
- type: `boolean`
- default: `false`


## `programs.niri.settings.layout.border.inactive-color`
- type: `string`
- default: `"rgb(80 80 80)"`


## `programs.niri.settings.layout.border.inactive-gradient`
- type: `null or (submodule)`
- default: `null`


## `programs.niri.settings.layout.border.inactive-gradient.angle`
- type: `signed integer`
- default: `180`


## `programs.niri.settings.layout.border.inactive-gradient.from`
- type: `string`


## `programs.niri.settings.layout.border.inactive-gradient.relative-to`
- type: `one of "window", "workspace-view"`
- default: `"window"`


## `programs.niri.settings.layout.border.inactive-gradient.to`
- type: `string`


## `programs.niri.settings.layout.border.width`
- type: `signed integer`
- default: `4`


## `programs.niri.settings.layout.center-focused-column`
- type: `one of "never", "always", "on-overflow"`
- default: `"never"`


## `programs.niri.settings.layout.default-column-width`
- type: `{} or (variant of: fixed | proportion)`


## `programs.niri.settings.layout.default-column-width.fixed`
- type: `signed integer`


## `programs.niri.settings.layout.default-column-width.proportion`
- type: `floating point number`


## `programs.niri.settings.layout.focus-ring.active-color`
- type: `string`
- default: `"rgb(127 200 255)"`


## `programs.niri.settings.layout.focus-ring.active-gradient`
- type: `null or (submodule)`
- default: `null`


## `programs.niri.settings.layout.focus-ring.active-gradient.angle`
- type: `signed integer`
- default: `180`


## `programs.niri.settings.layout.focus-ring.active-gradient.from`
- type: `string`


## `programs.niri.settings.layout.focus-ring.active-gradient.relative-to`
- type: `one of "window", "workspace-view"`
- default: `"window"`


## `programs.niri.settings.layout.focus-ring.active-gradient.to`
- type: `string`


## `programs.niri.settings.layout.focus-ring.enable`
- type: `boolean`
- default: `true`


## `programs.niri.settings.layout.focus-ring.inactive-color`
- type: `string`
- default: `"rgb(80 80 80)"`


## `programs.niri.settings.layout.focus-ring.inactive-gradient`
- type: `null or (submodule)`
- default: `null`


## `programs.niri.settings.layout.focus-ring.inactive-gradient.angle`
- type: `signed integer`
- default: `180`


## `programs.niri.settings.layout.focus-ring.inactive-gradient.from`
- type: `string`


## `programs.niri.settings.layout.focus-ring.inactive-gradient.relative-to`
- type: `one of "window", "workspace-view"`
- default: `"window"`


## `programs.niri.settings.layout.focus-ring.inactive-gradient.to`
- type: `string`


## `programs.niri.settings.layout.focus-ring.width`
- type: `signed integer`
- default: `4`


## `programs.niri.settings.layout.gaps`
- type: `signed integer`
- default: `16`


## `programs.niri.settings.layout.preset-column-widths`
- type: `list of variant of: fixed | proportion`


## `programs.niri.settings.layout.preset-column-widths.*.fixed`
- type: `signed integer`


## `programs.niri.settings.layout.preset-column-widths.*.proportion`
- type: `floating point number`


## `programs.niri.settings.layout.struts.bottom`
- type: `signed integer`
- default: `0`


## `programs.niri.settings.layout.struts.left`
- type: `signed integer`
- default: `0`


## `programs.niri.settings.layout.struts.right`
- type: `signed integer`
- default: `0`


## `programs.niri.settings.layout.struts.top`
- type: `signed integer`
- default: `0`


## `programs.niri.settings.outputs`
- type: `attribute set of (submodule)`


## `programs.niri.settings.outputs.<name>.enable`
- type: `boolean`
- default: `true`


## `programs.niri.settings.outputs.<name>.mode`
- type: `null or (submodule)`
- default: `null`


## `programs.niri.settings.outputs.<name>.mode.height`
- type: `signed integer`


## `programs.niri.settings.outputs.<name>.mode.refresh`
- type: `null or floating point number`
- default: `null`


## `programs.niri.settings.outputs.<name>.mode.width`
- type: `signed integer`


## `programs.niri.settings.outputs.<name>.position`
- type: `null or (submodule)`
- default: `null`


## `programs.niri.settings.outputs.<name>.position.x`
- type: `signed integer`


## `programs.niri.settings.outputs.<name>.position.y`
- type: `signed integer`


## `programs.niri.settings.outputs.<name>.scale`
- type: `floating point number`
- default: `1.000000`


## `programs.niri.settings.outputs.<name>.transform.flipped`
- type: `boolean`
- default: `false`


## `programs.niri.settings.outputs.<name>.transform.rotation`
- type: `one of 0, 90, 180, 270`
- default: `0`


## `programs.niri.settings.prefer-no-csd`
- type: `boolean`
- default: `false`


## `programs.niri.settings.screenshot-path`
- type: `null or string`
- default: `"~/Pictures/Screenshots/Screenshot from %Y-%m-%d %H-%M-%S.png"`


## `programs.niri.settings.spawn-at-startup`
- type: `list of (submodule)`


## `programs.niri.settings.spawn-at-startup.*.command`
- type: `list of string`


## `programs.niri.settings.window-rules`
- type: `list of (submodule)`


## `programs.niri.settings.window-rules.*.default-column-width`
- type: `null or {} or (variant of: fixed | proportion)`
- default: `null`


## `programs.niri.settings.window-rules.*.default-column-width.fixed`
- type: `signed integer`


## `programs.niri.settings.window-rules.*.default-column-width.proportion`
- type: `floating point number`


## `programs.niri.settings.window-rules.*.excludes`
- type: `list of (submodule)`


## `programs.niri.settings.window-rules.*.excludes.*.app-id`
- type: `null or string`
- default: `null`


## `programs.niri.settings.window-rules.*.excludes.*.title`
- type: `null or string`
- default: `null`


## `programs.niri.settings.window-rules.*.matches`
- type: `list of (submodule)`


## `programs.niri.settings.window-rules.*.matches.*.app-id`
- type: `null or string`
- default: `null`


## `programs.niri.settings.window-rules.*.matches.*.title`
- type: `null or string`
- default: `null`


## `programs.niri.settings.window-rules.*.open-fullscreen`
- type: `null or boolean`
- default: `null`


## `programs.niri.settings.window-rules.*.open-maximized`
- type: `null or boolean`
- default: `null`


## `programs.niri.settings.window-rules.*.open-on-output`
- type: `null or string`
- default: `null`
