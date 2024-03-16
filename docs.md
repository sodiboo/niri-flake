<!-- sorting key: _.a.nonmodules._ -->
# Packages provided by this flake

<!-- sorting key: _.a.nonmodules.a.packages.niri-stable -->
## `packages.<system>.niri-stable`

(where `<system>` is one of: `x86_64-linux`, `aarch64-linux`)

The latest stable tagged version of niri (currently [release `v0.1.3`](https://github.com/YaLTeR/niri/releases/tag/v0.1.3)), along with potential patches.


Note that the `aarch64-linux` package is untested. It might work, but i can't guarantee it.

Also note that you likely should not be using these outputs directly. Instead, you should use the overlay ([`overlays.niri`](#overlaysniri)).



<!-- sorting key: _.a.nonmodules.a.packages.niri-unstable -->
## `packages.<system>.niri-unstable`

(where `<system>` is one of: `x86_64-linux`, `aarch64-linux`)

The latest commit to the main branch of niri. This is refreshed hourly and may break at any time without prior notice.


Note that the `aarch64-linux` package is untested. It might work, but i can't guarantee it.

Also note that you likely should not be using these outputs directly. Instead, you should use the overlay ([`overlays.niri`](#overlaysniri)).



<!-- sorting key: _.a.nonmodules.b.overlay -->
## `overlays.niri`

A nixpkgs overlay that provides `niri-stable` and `niri-unstable`.

It is recommended to use this overlay over directly accessing the outputs. This is because the overlay ensures that the dependencies match your system's nixpkgs version, which is most important for `mesa`. If `mesa` doesn't match, niri will be unable to run in a TTY.

You can enable this overlay by adding this line to your configuration:

```nix
{
  nixpkgs.overlays = [ niri.overlays.niri ];
}
```

You can then access the packages via `pkgs.niri-stable` and `pkgs.niri-unstable` as if they were part of nixpkgs.



<!-- sorting key: _.b.modules.a.nixos._ -->
# `nixosModules.niri`

The full NixOS module for niri.

By default, this module does the following:

- It will enable a binary cache managed by me, sodiboo. This helps you avoid building niri from source, which can take a long time in release mode.
- If you have home-manager installed in your NixOS configuration (rather than as a standalone program), this module will automatically import [`homeModules.config`](#homemodulesconfig) for all users and give it the correct package to use for validation.
- If you have home-manager and stylix installed in your NixOS configuration, this module will also automatically import [`homeModules.stylix`](#homemodulesstylix) for all users.



<!-- sorting key: _.b.modules.a.nixos.enable -->
## `programs.niri.enable`

- type: `boolean`
- default: `false`

Whether to install and enable niri.

This also enables the necessary system components for niri to function properly, such as desktop portals and polkit.



<!-- sorting key: _.b.modules.a.nixos.package -->
## `programs.niri.package`

- type: `package`
- default: [`packages.<system>.niri-stable`](#packagessystemniri-stable)

The package that niri will use.

You may wish to set it to the following values:

- [`pkgs.niri`](https://search.nixos.org/packages?channel=unstable&show=niri)
- [`packages.<system>.niri-stable`](#packagessystemniri-stable)
- [`packages.<system>.niri-unstable`](#packagessystemniri-unstable)



<!-- sorting key: _.b.modules.a.nixos.z.cache -->
## `niri-flake.cache.enable`

- type: `boolean`
- default: `true`

Whether or not to enable the binary cache [`niri.cachix.org`](https://niri.cachix.org/) in your nix configuration.

Using a binary cache can save you time, by avoiding redundant rebuilds.

This cache is managed by me, sodiboo, and i use GitHub Actions to automaticaly upload builds of [`packages.<system>.niri-stable`](#packagessystemniri-stable) and [`packages.<system>.niri-unstable`](#packagessystemniri-unstable) (for nixpkgs unstable and stable). By using it, you are trusting me to not upload malicious builds, and as such you may disable it.

If you do not wish to use this cache, then you may wish to set [`programs.niri.package`](#programsniripackage) to [`pkgs.niri`](https://search.nixos.org/packages?channel=unstable&show=niri), in order to take advantage of the NixOS cache.



<!-- sorting key: _.b.modules.b.home._ -->
# `homeModules.niri`

The full home-manager module for niri.

By default, this module does nothing. It will import [`homeModules.config`](#homemodulesconfig), which provides many configuration options, and it also provides some options to install niri.



<!-- sorting key: _.b.modules.b.home.enable -->
## `programs.niri.enable`

- type: `boolean`
- default: `false`

Whether to install and enable niri.

This also enables the necessary system components for niri to function properly, such as desktop portals and polkit.



<!-- sorting key: _.b.modules.b.home.package -->
## `programs.niri.package`

- type: `package`
- default: [`packages.<system>.niri-stable`](#packagessystemniri-stable)

The package that niri will use.

You may wish to set it to the following values:

- [`pkgs.niri`](https://search.nixos.org/packages?channel=unstable&show=niri)
- [`packages.<system>.niri-stable`](#packagessystemniri-stable)
- [`packages.<system>.niri-unstable`](#packagessystemniri-unstable)



<!-- sorting key: _.b.modules.c.stylix._ -->
# `homeModules.stylix`

Stylix integration. It provides a target to enable niri.

This module is automatically imported if you have home-manager and stylix installed in your NixOS configuration.

If you use standalone home-manager, you must import it manually if you wish to use stylix with niri. (since it can't be automatically imported in that case)



<!-- sorting key: _.b.modules.c.stylix.target -->
## `stylix.targets.niri.enable`

- type: `boolean`
- default: [`stylix.autoEnable`](https://danth.github.io/stylix/options/hm.html#stylixautoenable)

Whether to style niri according to your stylix config.

Note that enabling this stylix target will cause a config file to be generated, even if you don't set [`programs.niri.config`](#programsniriconfig).

This also means that, with stylix installed, having everything set to default *does* generate an actual config file.



<!-- sorting key: _.z.pre-config._ -->
# `homeModules.config`

Configuration options for niri. This module is automatically imported by [`nixosModules.niri`](#nixosmodulesniri) and [`homeModules.niri`](#homemodulesniri).

By default, this module does nothing. It provides many configuration options for niri, such as keybindings, animations, and window rules.

When its options are set, it generates `$XDG_CONFIG_HOME/niri/config.kdl` for the user. This is the default path for niri's config file.

It will also validate the config file with the `niri validate` command before committing that config. This ensures that the config file is always valid, else your system will fail to build. When using [`programs.niri.settings`](#programsnirisettings) to configure niri, that's not necessary, because it will always generate a valid config file. But, if you set [`programs.niri.config`](#programsniriconfig) directly, then this is very useful.



<!-- sorting key: _.z.pre-config.a.variant -->
## type: `variant of`

Some of the options below make use of a "variant" type.

This is a type that behaves similarly to a submodule, except you can only set *one* of its suboptions.

An example of this usage is in [`programs.niri.settings.animations.<name>`](#programsnirisettingsanimationsname), where each event can have either an easing animation or a spring animation. \
You cannot set parameters for both, so `variant` is used here.


<!-- sorting key: _.z.pre-config.b.package -->
## `programs.niri.package`

- type: `package`
- default: [`packages.<system>.niri-stable`](#packagessystemniri-stable)

The `niri` package that the config is validated against. This cannot be modified if you set the identically-named option in [`nixosModules.niri`](#nixosmodulesniri) or [`homeModules.niri`](#homemodulesniri).



<!-- sorting key: programs.niri.config -->
## `programs.niri.config`
- type: `null or string or kdl document`

The niri config file.

- When this is null, no config file is generated.
- When this is a string, it is assumed to be the config file contents.
- When this is kdl document, it is serialized to a string before being used as the config file contents.

By default, this is a KDL document that reflects the settings in [`programs.niri.settings`](#programsnirisettings).


<!-- sorting key: programs.niri.finalConfig -->
## `programs.niri.finalConfig`
- type: `null or string`

The final niri config file contents.

This is a string that reflects the document stored in [`programs.niri.config`](#programsniriconfig).

It is exposed mainly for debugging purposes, such as when you need to inspect how a certain option affects the resulting config file.


<!-- sorting key: programs.niri.settings -->
## `programs.niri.settings`
- type: `null or (submodule)`
- default: `null`

Nix-native settings for niri.

By default, when this is null, no config file is generated.

Beware that setting [`programs.niri.config`](#programsniriconfig) completely overrides everything under this option.


<!-- sorting key: programs.niri.settings.a.input.keyboard.repeat-delay -->
## `programs.niri.settings.input.keyboard.repeat-delay`
- type: `signed integer`
- default: `600`


<!-- sorting key: programs.niri.settings.a.input.keyboard.repeat-rate -->
## `programs.niri.settings.input.keyboard.repeat-rate`
- type: `signed integer`
- default: `25`


<!-- sorting key: programs.niri.settings.a.input.keyboard.track-layout -->
## `programs.niri.settings.input.keyboard.track-layout`
- type: `one of "global", "window"`
- default: `"global"`


<!-- sorting key: programs.niri.settings.a.input.keyboard.xkb.layout -->
## `programs.niri.settings.input.keyboard.xkb.layout`
- type: `null or string`
- default: `null`


<!-- sorting key: programs.niri.settings.a.input.keyboard.xkb.model -->
## `programs.niri.settings.input.keyboard.xkb.model`
- type: `null or string`
- default: `null`


<!-- sorting key: programs.niri.settings.a.input.keyboard.xkb.options -->
## `programs.niri.settings.input.keyboard.xkb.options`
- type: `null or string`
- default: `null`


<!-- sorting key: programs.niri.settings.a.input.keyboard.xkb.rules -->
## `programs.niri.settings.input.keyboard.xkb.rules`
- type: `null or string`
- default: `null`


<!-- sorting key: programs.niri.settings.a.input.keyboard.xkb.variant -->
## `programs.niri.settings.input.keyboard.xkb.variant`
- type: `null or string`
- default: `null`


<!-- sorting key: programs.niri.settings.a.input.mouse.accel-profile -->
## `programs.niri.settings.input.mouse.accel-profile`
- type: `null or one of "adaptive", "flat"`
- default: `null`


<!-- sorting key: programs.niri.settings.a.input.mouse.accel-speed -->
## `programs.niri.settings.input.mouse.accel-speed`
- type: `floating point number`
- default: `0.000000`


<!-- sorting key: programs.niri.settings.a.input.mouse.natural-scroll -->
## `programs.niri.settings.input.mouse.natural-scroll`
- type: `boolean`
- default: `false`


<!-- sorting key: programs.niri.settings.a.input.power-key-handling.enable -->
## `programs.niri.settings.input.power-key-handling.enable`
- type: `boolean`
- default: `true`


<!-- sorting key: programs.niri.settings.a.input.tablet.map-to-output -->
## `programs.niri.settings.input.tablet.map-to-output`
- type: `null or string`
- default: `null`


<!-- sorting key: programs.niri.settings.a.input.touch.map-to-output -->
## `programs.niri.settings.input.touch.map-to-output`
- type: `null or string`
- default: `null`


<!-- sorting key: programs.niri.settings.a.input.touchpad.accel-profile -->
## `programs.niri.settings.input.touchpad.accel-profile`
- type: `null or one of "adaptive", "flat"`
- default: `null`


<!-- sorting key: programs.niri.settings.a.input.touchpad.accel-speed -->
## `programs.niri.settings.input.touchpad.accel-speed`
- type: `floating point number`
- default: `0.000000`


<!-- sorting key: programs.niri.settings.a.input.touchpad.dwt -->
## `programs.niri.settings.input.touchpad.dwt`
- type: `boolean`
- default: `false`


<!-- sorting key: programs.niri.settings.a.input.touchpad.dwtp -->
## `programs.niri.settings.input.touchpad.dwtp`
- type: `boolean`
- default: `false`


<!-- sorting key: programs.niri.settings.a.input.touchpad.natural-scroll -->
## `programs.niri.settings.input.touchpad.natural-scroll`
- type: `boolean`
- default: `true`


<!-- sorting key: programs.niri.settings.a.input.touchpad.tap -->
## `programs.niri.settings.input.touchpad.tap`
- type: `boolean`
- default: `true`


<!-- sorting key: programs.niri.settings.a.input.touchpad.tap-button-map -->
## `programs.niri.settings.input.touchpad.tap-button-map`
- type: `null or one of "left-middle-right", "left-right-middle"`
- default: `null`


<!-- sorting key: programs.niri.settings.a.input.trackpoint.accel-profile -->
## `programs.niri.settings.input.trackpoint.accel-profile`
- type: `null or one of "adaptive", "flat"`
- default: `null`


<!-- sorting key: programs.niri.settings.a.input.trackpoint.accel-speed -->
## `programs.niri.settings.input.trackpoint.accel-speed`
- type: `floating point number`
- default: `0.000000`


<!-- sorting key: programs.niri.settings.a.input.trackpoint.natural-scroll -->
## `programs.niri.settings.input.trackpoint.natural-scroll`
- type: `boolean`
- default: `false`


<!-- sorting key: programs.niri.settings.b.outputs -->
## `programs.niri.settings.outputs`
- type: `attribute set of (submodule)`


<!-- sorting key: programs.niri.settings.b.outputs.enable -->
## `programs.niri.settings.outputs.<name>.enable`
- type: `boolean`
- default: `true`


<!-- sorting key: programs.niri.settings.b.outputs.mode -->
## `programs.niri.settings.outputs.<name>.mode`
- type: `null or (submodule)`
- default: `null`


<!-- sorting key: programs.niri.settings.b.outputs.mode.height -->
## `programs.niri.settings.outputs.<name>.mode.height`
- type: `signed integer`


<!-- sorting key: programs.niri.settings.b.outputs.mode.refresh -->
## `programs.niri.settings.outputs.<name>.mode.refresh`
- type: `null or floating point number`
- default: `null`


<!-- sorting key: programs.niri.settings.b.outputs.mode.width -->
## `programs.niri.settings.outputs.<name>.mode.width`
- type: `signed integer`


<!-- sorting key: programs.niri.settings.b.outputs.position -->
## `programs.niri.settings.outputs.<name>.position`
- type: `null or (submodule)`
- default: `null`


<!-- sorting key: programs.niri.settings.b.outputs.position.x -->
## `programs.niri.settings.outputs.<name>.position.x`
- type: `signed integer`


<!-- sorting key: programs.niri.settings.b.outputs.position.y -->
## `programs.niri.settings.outputs.<name>.position.y`
- type: `signed integer`


<!-- sorting key: programs.niri.settings.b.outputs.scale -->
## `programs.niri.settings.outputs.<name>.scale`
- type: `floating point number`
- default: `1.000000`


<!-- sorting key: programs.niri.settings.b.outputs.transform.flipped -->
## `programs.niri.settings.outputs.<name>.transform.flipped`
- type: `boolean`
- default: `false`


<!-- sorting key: programs.niri.settings.b.outputs.transform.rotation -->
## `programs.niri.settings.outputs.<name>.transform.rotation`
- type: `one of 0, 90, 180, 270`
- default: `0`


<!-- sorting key: programs.niri.settings.c.cursor.size -->
## `programs.niri.settings.cursor.size`
- type: `signed integer`
- default: `24`


<!-- sorting key: programs.niri.settings.c.cursor.theme -->
## `programs.niri.settings.cursor.theme`
- type: `string`
- default: `"default"`


<!-- sorting key: programs.niri.settings.d.screenshot-path -->
## `programs.niri.settings.screenshot-path`
- type: `null or string`
- default: `"~/Pictures/Screenshots/Screenshot from %Y-%m-%d %H-%M-%S.png"`


<!-- sorting key: programs.niri.settings.e.hotkey-overlay.skip-at-startup -->
## `programs.niri.settings.hotkey-overlay.skip-at-startup`
- type: `boolean`
- default: `false`


<!-- sorting key: programs.niri.settings.f.prefer-no-csd -->
## `programs.niri.settings.prefer-no-csd`
- type: `boolean`
- default: `false`


<!-- sorting key: programs.niri.settings.g.layout.border.active-color -->
## `programs.niri.settings.layout.border.active-color`
- type: `string`
- default: `"rgb(255 200 127)"`


<!-- sorting key: programs.niri.settings.g.layout.border.active-gradient -->
## `programs.niri.settings.layout.border.active-gradient`
- type: `null or (submodule)`
- default: `null`


<!-- sorting key: programs.niri.settings.g.layout.border.active-gradient.angle -->
## `programs.niri.settings.layout.border.active-gradient.angle`
- type: `signed integer`
- default: `180`


<!-- sorting key: programs.niri.settings.g.layout.border.active-gradient.from -->
## `programs.niri.settings.layout.border.active-gradient.from`
- type: `string`


<!-- sorting key: programs.niri.settings.g.layout.border.active-gradient.relative-to -->
## `programs.niri.settings.layout.border.active-gradient.relative-to`
- type: `one of "window", "workspace-view"`
- default: `"window"`


<!-- sorting key: programs.niri.settings.g.layout.border.active-gradient.to -->
## `programs.niri.settings.layout.border.active-gradient.to`
- type: `string`


<!-- sorting key: programs.niri.settings.g.layout.border.enable -->
## `programs.niri.settings.layout.border.enable`
- type: `boolean`
- default: `false`


<!-- sorting key: programs.niri.settings.g.layout.border.inactive-color -->
## `programs.niri.settings.layout.border.inactive-color`
- type: `string`
- default: `"rgb(80 80 80)"`


<!-- sorting key: programs.niri.settings.g.layout.border.inactive-gradient -->
## `programs.niri.settings.layout.border.inactive-gradient`
- type: `null or (submodule)`
- default: `null`


<!-- sorting key: programs.niri.settings.g.layout.border.inactive-gradient.angle -->
## `programs.niri.settings.layout.border.inactive-gradient.angle`
- type: `signed integer`
- default: `180`


<!-- sorting key: programs.niri.settings.g.layout.border.inactive-gradient.from -->
## `programs.niri.settings.layout.border.inactive-gradient.from`
- type: `string`


<!-- sorting key: programs.niri.settings.g.layout.border.inactive-gradient.relative-to -->
## `programs.niri.settings.layout.border.inactive-gradient.relative-to`
- type: `one of "window", "workspace-view"`
- default: `"window"`


<!-- sorting key: programs.niri.settings.g.layout.border.inactive-gradient.to -->
## `programs.niri.settings.layout.border.inactive-gradient.to`
- type: `string`


<!-- sorting key: programs.niri.settings.g.layout.border.width -->
## `programs.niri.settings.layout.border.width`
- type: `signed integer`
- default: `4`


<!-- sorting key: programs.niri.settings.g.layout.center-focused-column -->
## `programs.niri.settings.layout.center-focused-column`
- type: `one of "never", "always", "on-overflow"`
- default: `"never"`


<!-- sorting key: programs.niri.settings.g.layout.default-column-width -->
## `programs.niri.settings.layout.default-column-width`
- type: `{} or (variant of: fixed | proportion)`


<!-- sorting key: programs.niri.settings.g.layout.default-column-width.fixed -->
## `programs.niri.settings.layout.default-column-width.fixed`
- type: `signed integer`


<!-- sorting key: programs.niri.settings.g.layout.default-column-width.proportion -->
## `programs.niri.settings.layout.default-column-width.proportion`
- type: `floating point number`


<!-- sorting key: programs.niri.settings.g.layout.focus-ring.active-color -->
## `programs.niri.settings.layout.focus-ring.active-color`
- type: `string`
- default: `"rgb(127 200 255)"`


<!-- sorting key: programs.niri.settings.g.layout.focus-ring.active-gradient -->
## `programs.niri.settings.layout.focus-ring.active-gradient`
- type: `null or (submodule)`
- default: `null`


<!-- sorting key: programs.niri.settings.g.layout.focus-ring.active-gradient.angle -->
## `programs.niri.settings.layout.focus-ring.active-gradient.angle`
- type: `signed integer`
- default: `180`


<!-- sorting key: programs.niri.settings.g.layout.focus-ring.active-gradient.from -->
## `programs.niri.settings.layout.focus-ring.active-gradient.from`
- type: `string`


<!-- sorting key: programs.niri.settings.g.layout.focus-ring.active-gradient.relative-to -->
## `programs.niri.settings.layout.focus-ring.active-gradient.relative-to`
- type: `one of "window", "workspace-view"`
- default: `"window"`


<!-- sorting key: programs.niri.settings.g.layout.focus-ring.active-gradient.to -->
## `programs.niri.settings.layout.focus-ring.active-gradient.to`
- type: `string`


<!-- sorting key: programs.niri.settings.g.layout.focus-ring.enable -->
## `programs.niri.settings.layout.focus-ring.enable`
- type: `boolean`
- default: `true`


<!-- sorting key: programs.niri.settings.g.layout.focus-ring.inactive-color -->
## `programs.niri.settings.layout.focus-ring.inactive-color`
- type: `string`
- default: `"rgb(80 80 80)"`


<!-- sorting key: programs.niri.settings.g.layout.focus-ring.inactive-gradient -->
## `programs.niri.settings.layout.focus-ring.inactive-gradient`
- type: `null or (submodule)`
- default: `null`


<!-- sorting key: programs.niri.settings.g.layout.focus-ring.inactive-gradient.angle -->
## `programs.niri.settings.layout.focus-ring.inactive-gradient.angle`
- type: `signed integer`
- default: `180`


<!-- sorting key: programs.niri.settings.g.layout.focus-ring.inactive-gradient.from -->
## `programs.niri.settings.layout.focus-ring.inactive-gradient.from`
- type: `string`


<!-- sorting key: programs.niri.settings.g.layout.focus-ring.inactive-gradient.relative-to -->
## `programs.niri.settings.layout.focus-ring.inactive-gradient.relative-to`
- type: `one of "window", "workspace-view"`
- default: `"window"`


<!-- sorting key: programs.niri.settings.g.layout.focus-ring.inactive-gradient.to -->
## `programs.niri.settings.layout.focus-ring.inactive-gradient.to`
- type: `string`


<!-- sorting key: programs.niri.settings.g.layout.focus-ring.width -->
## `programs.niri.settings.layout.focus-ring.width`
- type: `signed integer`
- default: `4`


<!-- sorting key: programs.niri.settings.g.layout.gaps -->
## `programs.niri.settings.layout.gaps`
- type: `signed integer`
- default: `16`


<!-- sorting key: programs.niri.settings.g.layout.preset-column-widths -->
## `programs.niri.settings.layout.preset-column-widths`
- type: `list of variant of: fixed | proportion`


<!-- sorting key: programs.niri.settings.g.layout.preset-column-widths.fixed -->
## `programs.niri.settings.layout.preset-column-widths.*.fixed`
- type: `signed integer`


<!-- sorting key: programs.niri.settings.g.layout.preset-column-widths.proportion -->
## `programs.niri.settings.layout.preset-column-widths.*.proportion`
- type: `floating point number`


<!-- sorting key: programs.niri.settings.g.layout.struts.bottom -->
## `programs.niri.settings.layout.struts.bottom`
- type: `signed integer`
- default: `0`


<!-- sorting key: programs.niri.settings.g.layout.struts.left -->
## `programs.niri.settings.layout.struts.left`
- type: `signed integer`
- default: `0`


<!-- sorting key: programs.niri.settings.g.layout.struts.right -->
## `programs.niri.settings.layout.struts.right`
- type: `signed integer`
- default: `0`


<!-- sorting key: programs.niri.settings.g.layout.struts.top -->
## `programs.niri.settings.layout.struts.top`
- type: `signed integer`
- default: `0`


<!-- sorting key: programs.niri.settings.h.spawn-at-startup -->
## `programs.niri.settings.spawn-at-startup`
- type: `list of (submodule)`


<!-- sorting key: programs.niri.settings.h.spawn-at-startup.command -->
## `programs.niri.settings.spawn-at-startup.*.command`
- type: `list of string`


<!-- sorting key: programs.niri.settings.i.binds -->
## `programs.niri.settings.binds`
- type: `attribute set of (string or kdl leaf)`

Keybindings for niri.

This is a mapping of keybindings to "actions".

An action is an attrset with a single key, being the name, and a value that is a list of its arguments. For example, to represent a spawn action, you could do this:

```nix
{
  programs.niri.settings.binds = {
    "XF86AudioRaiseVolume".spawn = ["wpctl" "set-volume" "@DEFAULT_AUDIO_SINK@" "0.1+"];
    "XF86AudioLowerVolume".spawn = ["wpctl" "set-volume" "@DEFAULT_AUDIO_SINK@" "0.1-"];
  };
}
```

If there is only a single argument, you can pass it directly. It will be implicitly converted to a list in that case.

```nix
{
  programs.niri.settings.binds = {
    "Mod+D".spawn = "fuzzel";
  };
}
```

For actions taking no arguments, you should pass it an empty array.

```nix
{
  programs.niri.settings.binds = {
    "Mod+Q".close-window = [];
  };
}
```

In this simple case, you can also use a string instead of an arrset.

```nix
{
  programs.niri.settings.binds = {
    "Mod+Q" = "close-window";
  };
}
```

In the future, i might implement a way to define actions with some kind of type checking, and in that case, the arrset form will be the only accepted shape. But, for now, strings may look nicer for simple cases.

Note that the arguments are not limited to strings:

```nix
{
  programs.niri.settings.binds = {
    "Mod+Ctrl+5".move-column-to-workspace = 5;
  };
}
```

And if an action takes *properties* (unordered key-value) as well as *arguments* (ordered value), then you can pass the propset as the *last* argument to the action.

```nix
{
  programs.niri.settings.binds = {
    "Mod+Shift+E".quit = [{skip-confirmation = true;}];
  };
}
```

But of course, you can also elide the array if there aren't any other arguments.

```nix
{
  programs.niri.settings.binds = {
    "Mod+Shift+E".quit = {skip-confirmation = true;};
  };
}
```

And it's written even simpler like so:

```nix
{
  programs.niri.settings.binds = {
    "Mod+Shift+E".quit.skip-confirmation = true;
  };
}
```

Although the nix module does *not* verify the correctness of the keybindings, it will ask niri to validate the config file before committing it. This ensures that you won't accidentally build a system with an invalid niri config.


<!-- sorting key: programs.niri.settings.j.animations -->
<!-- programs.niri.settings.animations -->

<!-- sorting key: programs.niri.settings.j.animations.a.opts.enable -->
## `programs.niri.settings.animations.enable`
- type: `boolean`
- default: `true`


<!-- sorting key: programs.niri.settings.j.animations.a.opts.slowdown -->
## `programs.niri.settings.animations.slowdown`
- type: `floating point number`
- default: `1.000000`


<!-- sorting key: programs.niri.settings.j.animations.b.submodule -->
## `programs.niri.settings.animations.<name>`
- type: `animation`, which is a `variant of: easing | spring`


<!-- sorting key: programs.niri.settings.j.animations.b.submodule.easing -->
<!-- programs.niri.settings.animations.<name>.easing -->

<!-- sorting key: programs.niri.settings.j.animations.b.submodule.easing.curve -->
## `programs.niri.settings.animations.<name>.easing.curve`
- type: `one of "ease-out-cubic", "ease-out-expo"`


<!-- sorting key: programs.niri.settings.j.animations.b.submodule.easing.duration-ms -->
## `programs.niri.settings.animations.<name>.easing.duration-ms`
- type: `signed integer`


<!-- sorting key: programs.niri.settings.j.animations.b.submodule.spring -->
<!-- programs.niri.settings.animations.<name>.spring -->

<!-- sorting key: programs.niri.settings.j.animations.b.submodule.spring.damping-ratio -->
## `programs.niri.settings.animations.<name>.spring.damping-ratio`
- type: `floating point number`


<!-- sorting key: programs.niri.settings.j.animations.b.submodule.spring.epsilon -->
## `programs.niri.settings.animations.<name>.spring.epsilon`
- type: `floating point number`


<!-- sorting key: programs.niri.settings.j.animations.b.submodule.spring.stiffness -->
## `programs.niri.settings.animations.<name>.spring.stiffness`
- type: `signed integer`


<!-- sorting key: programs.niri.settings.j.animations.c.defaults.anims.config-notification-open-close -->
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



<!-- sorting key: programs.niri.settings.j.animations.c.defaults.anims.horizontal-view-movement -->
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



<!-- sorting key: programs.niri.settings.j.animations.c.defaults.anims.window-open -->
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



<!-- sorting key: programs.niri.settings.j.animations.c.defaults.anims.workspace-switch -->
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



<!-- sorting key: programs.niri.settings.k.environment -->
## `programs.niri.settings.environment`
- type: `attribute set of (null or string)`

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


<!-- sorting key: programs.niri.settings.l.window-rules -->
## `programs.niri.settings.window-rules`
- type: `list of (submodule)`


<!-- sorting key: programs.niri.settings.l.window-rules.default-column-width -->
## `programs.niri.settings.window-rules.*.default-column-width`
- type: `null or {} or (variant of: fixed | proportion)`
- default: `null`


<!-- sorting key: programs.niri.settings.l.window-rules.default-column-width.fixed -->
## `programs.niri.settings.window-rules.*.default-column-width.fixed`
- type: `signed integer`


<!-- sorting key: programs.niri.settings.l.window-rules.default-column-width.proportion -->
## `programs.niri.settings.window-rules.*.default-column-width.proportion`
- type: `floating point number`


<!-- sorting key: programs.niri.settings.l.window-rules.excludes -->
## `programs.niri.settings.window-rules.*.excludes`
- type: `list of (submodule)`


<!-- sorting key: programs.niri.settings.l.window-rules.excludes.app-id -->
## `programs.niri.settings.window-rules.*.excludes.*.app-id`
- type: `null or string`
- default: `null`


<!-- sorting key: programs.niri.settings.l.window-rules.excludes.title -->
## `programs.niri.settings.window-rules.*.excludes.*.title`
- type: `null or string`
- default: `null`


<!-- sorting key: programs.niri.settings.l.window-rules.matches -->
## `programs.niri.settings.window-rules.*.matches`
- type: `list of (submodule)`


<!-- sorting key: programs.niri.settings.l.window-rules.matches.app-id -->
## `programs.niri.settings.window-rules.*.matches.*.app-id`
- type: `null or string`
- default: `null`


<!-- sorting key: programs.niri.settings.l.window-rules.matches.title -->
## `programs.niri.settings.window-rules.*.matches.*.title`
- type: `null or string`
- default: `null`


<!-- sorting key: programs.niri.settings.l.window-rules.open-fullscreen -->
## `programs.niri.settings.window-rules.*.open-fullscreen`
- type: `null or boolean`
- default: `null`


<!-- sorting key: programs.niri.settings.l.window-rules.open-maximized -->
## `programs.niri.settings.window-rules.*.open-maximized`
- type: `null or boolean`
- default: `null`


<!-- sorting key: programs.niri.settings.l.window-rules.open-on-output -->
## `programs.niri.settings.window-rules.*.open-on-output`
- type: `null or string`
- default: `null`


<!-- sorting key: programs.niri.settings.m.debug -->
## `programs.niri.settings.debug`
- type: `null or (attribute set of kdl arguments)`
- default: `null`

Debug options for niri.

`kdl arguments` in the type refers to a list of arguments passed to a node under the `debug` section. This is a way to pass arbitrary KDL-valid data to niri. See [`programs.niri.settings.binds`](#programsnirisettingsbinds) for more information on all the ways you can use this.

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

This option is, just like [`programs.niri.settings.binds`](#programsnirisettingsbinds), not verified by the nix module. But, it will be validated by niri before committing the config.

Additionally, i don't guarantee stability of the debug options. They may change at any time without prior notice, either because of niri changing the available options, or because of me changing this to a more reasonable schema.
