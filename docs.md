<!-- sorting key: _.a.nonmodules._ -->
# Packages provided by this flake

<!-- sorting key: _.a.nonmodules.a.packages._ -->
## `packages.<system>.<name>`

(where `<system>` is one of: `x86_64-linux`, `aarch64-linux`)

> [!important]
> Packages for `aarch64-linux` are untested. They might work, but i can't guarantee it.

You should preferably not be using these outputs directly. Instead, you should use [`overlays.niri`](#overlaysniri).



<!-- sorting key: _.a.nonmodules.a.packages.niri-stable -->
## `packages.<system>.niri-stable`

The latest stable tagged version of niri, along with potential patches.

Currently, this is release [`v0.1.3`](https://github.com/YaLTeR/niri/releases/tag/v0.1.3) plus the following patches:

- [`40cec34aa4a7f99ab12b30cba1a0ee83a706a413`](https://github.com/YaLTeR/niri/commit/40cec34aa4a7f99ab12b30cba1a0ee83a706a413)


To access this package under `pkgs.niri-stable`, you should use [`overlays.niri`](#overlaysniri).



<!-- sorting key: _.a.nonmodules.a.packages.niri-unstable -->
## `packages.<system>.niri-unstable`

The latest commit to the development branch of niri.

Currently, this is exactly commit [`db49deb`](https://github.com/YaLTeR/niri/tree/db49deb7fd2fbe805ceec060aa4dec65009ad7a7) which was authored on `2024-03-19 14:29:13`.

> [!warning]
> `niri-unstable` is not a released version, there are no stability guarantees, and it may break your workflow from itme to time.
>
> The specific package provided by this flake is automatically updated without any testing. The only guarantee is that it builds.


To access this package under `pkgs.niri-unstable`, you should use [`overlays.niri`](#overlaysniri).



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
- default: [`pkgs.niri-stable`](#packagessystemniri-stable)

The package that niri will use.

You may wish to set it to the following values:

- [`pkgs.niri`](https://search.nixos.org/packages?channel=unstable&show=niri)
- [`pkgs.niri-stable`](#packagessystemniri-stable)
- [`pkgs.niri-unstable`](#packagessystemniri-unstable)



<!-- sorting key: _.b.modules.a.nixos.z.cache -->
## `niri-flake.cache.enable`

- type: `boolean`
- default: `true`

Whether or not to enable the binary cache [`niri.cachix.org`](https://niri.cachix.org/) in your nix configuration.

Using a binary cache can save you time, by avoiding redundant rebuilds.

This cache is managed by me, sodiboo, and i use GitHub Actions to automaticaly upload builds of [`pkgs.niri-stable`](#packagessystemniri-stable) and [`pkgs.niri-unstable`](#packagessystemniri-unstable) (for nixpkgs unstable and stable). By using it, you are trusting me to not upload malicious builds, and as such you may disable it.

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
- default: [`pkgs.niri-stable`](#packagessystemniri-stable)

The package that niri will use.

You may wish to set it to the following values:

- [`pkgs.niri`](https://search.nixos.org/packages?channel=unstable&show=niri)
- [`pkgs.niri-stable`](#packagessystemniri-stable)
- [`pkgs.niri-unstable`](#packagessystemniri-unstable)



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

An example of this usage is in [`animations.<name>`](#programsnirisettingsanimationsname), where each event can have either an easing animation or a spring animation. \
You cannot set parameters for both, so `variant` is used here.


<!-- sorting key: _.z.pre-config.b.package -->
## `programs.niri.package`

- type: `package`
- default: [`pkgs.niri-stable`](#packagessystemniri-stable)

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


<!-- sorting key: programs.niri.settings.a.binds -->
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
    "Mod+1".focus-workspace = 1;
  };
}
```

For actions taking properties (named arguments), you can pass an attrset.

```nix
{
  programs.niri.settings.binds = {
    "Mod+Shift+E".quit.skip-confirmation = true;
  };
}
```

There is also a `binds` attrset available under each of the packages from this flake. It has attributes for each action.

> [!note]
> Note that although this interface is stable, its location is *not* stable. I've only just implemented this "magic leaf" kind of varargs function. I put it under each package for now, but that may change in the near future.

Usage is like so:

```nix
{
  programs.niri.settings.binds = with config.programs.niri.package.binds; {
    "XF86AudioRaiseVolume" = spawn "wpctl" "set-volume" "@DEFAULT_AUDIO_SINK@" "0.1+";
    "XF86AudioLowerVolume" = spawn "wpctl" "set-volume" "@DEFAULT_AUDIO_SINK@" "0.1-";

    "Mod+D" = spawn "fuzzel";
    "Mod+1" = focus-workspace 1;

    "Mod+Shift+E" = quit;
    "Mod+Ctrl+Shift+E" = quit { skip-confirmation=true; };

    "Mod+Plus" = set-column-width "+10%";
  }
}
```

These are the available actions:

- `center-column`
- `close-window`
- `consume-or-expel-window-left`
- `consume-or-expel-window-right`
- `consume-window-into-column`
- `expel-window-from-column`
- `focus-column-first`
- `focus-column-last`
- `focus-column-left`
- `focus-column-right`
- `focus-monitor-down`
- `focus-monitor-left`
- `focus-monitor-right`
- `focus-monitor-up`
- `focus-window-down`
- `focus-window-or-workspace-down`
- `focus-window-or-workspace-up`
- `focus-window-up`
- `focus-workspace`
- `focus-workspace-down`
- `focus-workspace-up`
- `fullscreen-window`
- `maximize-column`
- `move-column-left`
- `move-column-right`
- `move-column-to-first`
- `move-column-to-last`
- `move-column-to-monitor-down`
- `move-column-to-monitor-left`
- `move-column-to-monitor-right`
- `move-column-to-monitor-up`
- `move-column-to-workspace`
- `move-column-to-workspace-down`
- `move-column-to-workspace-up`
- `move-window-down`
- `move-window-down-or-to-workspace-down`
- `move-window-to-monitor-down`
- `move-window-to-monitor-left`
- `move-window-to-monitor-right`
- `move-window-to-monitor-up`
- `move-window-to-workspace`
- `move-window-to-workspace-down`
- `move-window-to-workspace-up`
- `move-window-up`
- `move-window-up-or-to-workspace-up`
- `move-workspace-down`
- `move-workspace-to-monitor-down`
- `move-workspace-to-monitor-left`
- `move-workspace-to-monitor-right`
- `move-workspace-to-monitor-up`
- `move-workspace-up`
- `power-off-monitors`
- `quit`
- `screenshot`
- `screenshot-screen`
- `screenshot-window`
- `set-column-width`
- `set-window-height`
- `show-hotkey-overlay`
- `spawn`
- `suspend`
- `switch-layout`
- `switch-preset-column-width`
- `toggle-debug-tint`
- `focus-workspace-previous` (only on `niri-unstable`)

No distinction is made between actions that take arguments and those that don't. Their usages are the exact same.


<!-- sorting key: programs.niri.settings.b.screenshot-path -->
## `programs.niri.settings.screenshot-path`
- type: `null or string`
- default: `"~/Pictures/Screenshots/Screenshot from %Y-%m-%d %H-%M-%S.png"`

The path to save screenshots to.

If this is null, then no screenshots will be saved.

If the path starts with a `~`, then it will be expanded to the user's home directory.

The path is then passed to [`stftime(3)`](https://man7.org/linux/man-pages/man3/strftime.3.html) with the current time, and the result is used as the final path.


<!-- sorting key: programs.niri.settings.c.hotkey-overlay.skip-at-startup -->
## `programs.niri.settings.hotkey-overlay.skip-at-startup`
- type: `boolean`
- default: `false`

Whether to skip the hotkey overlay shown when niri starts.


<!-- sorting key: programs.niri.settings.d.prefer-no-csd -->
## `programs.niri.settings.prefer-no-csd`
- type: `boolean`
- default: `false`

Whether to prefer server-side decorations (SSD) over client-side decorations (CSD).


<!-- sorting key: programs.niri.settings.e.spawn-at-startup -->
## `programs.niri.settings.spawn-at-startup`
- type: `list of (submodule)`


<!-- sorting key: programs.niri.settings.e.spawn-at-startup.command -->
## `programs.niri.settings.spawn-at-startup.*.command`
- type: `list of string`


<!-- sorting key: programs.niri.settings.f.input.focus-follows-mouse -->
## `programs.niri.settings.input.focus-follows-mouse`
- type: `boolean`
- default: `false`

> [!important]
> This option is not yet available in stable niri.
>
> If you wish to modify this option, you should make sure [`programs.niri.package`](#programsniripackage) is set to [`pkgs.niri-unstable`](#packagessystemniri-unstable).
>
> Otherwise, your system might fail to build.


Whether to focus the window under the mouse when the mouse moves.


<!-- sorting key: programs.niri.settings.f.input.keyboard.repeat-delay -->
## `programs.niri.settings.input.keyboard.repeat-delay`
- type: `signed integer`
- default: `600`

The delay in milliseconds before a key starts repeating.


<!-- sorting key: programs.niri.settings.f.input.keyboard.repeat-rate -->
## `programs.niri.settings.input.keyboard.repeat-rate`
- type: `signed integer`
- default: `25`

The rate in characters per second at which a key repeats.


<!-- sorting key: programs.niri.settings.f.input.keyboard.track-layout -->
## `programs.niri.settings.input.keyboard.track-layout`
- type: `one of "global", "window"`
- default: `"global"`

The keyboard layout can be remembered per `"window"`, such that when you switch to a window, the keyboard layout is set to the one that was last used in that window.

By default, there is only one `"global"` keyboard layout and changing it in any window will affect the keyboard layout used in all other windows too.


<!-- sorting key: programs.niri.settings.f.input.keyboard.xkb -->
## `programs.niri.settings.input.keyboard.xkb`


Parameters passed to libxkbcommon, which handles the keyboard in niri.

Further reading:
- [`smithay::wayland::seat::XkbConfig`](https://docs.rs/smithay/latest/smithay/wayland/seat/struct.XkbConfig.html)


<!-- sorting key: programs.niri.settings.f.input.keyboard.xkb.layout -->
## `programs.niri.settings.input.keyboard.xkb.layout`
- type: `string`
- default: `"us"`

A comma-separated list of layouts (languages) to include in the keymap.

Note that niri will set this to `"us"` by default, when unspecified.

See [`xkeyboard-config(7)`](https://man.archlinux.org/man/xkeyboard-config.7#LAYOUTS) for a list of available layouts and their variants.

If this is set to an empty string, the layout will be read from the `XKB_DEFAULT_LAYOUT` environment variable.



<!-- sorting key: programs.niri.settings.f.input.keyboard.xkb.model -->
## `programs.niri.settings.input.keyboard.xkb.model`
- type: `string`
- default: `""`

The keyboard model by which to interpret keycodes and LEDs

See [`xkeyboard-config(7)`](https://man.archlinux.org/man/xkeyboard-config.7#MODELS) for a list of available models.

If this is set to an empty string, the model will be read from the `XKB_DEFAULT_MODEL` environment variable.



<!-- sorting key: programs.niri.settings.f.input.keyboard.xkb.options -->
## `programs.niri.settings.input.keyboard.xkb.options`
- type: `null or string`
- default: `null`

A comma separated list of options, through which the user specifies non-layout related preferences, like which key combinations are used for switching layouts, or which key is the Compose key.

See [`xkeyboard-config(7)`](https://man.archlinux.org/man/xkeyboard-config.7#OPTIONS) for a list of available options.

If this is set to an empty string, no options will be used.

If this is set to null, the options will be read from the `XKB_DEFAULT_OPTIONS` environment variable.



<!-- sorting key: programs.niri.settings.f.input.keyboard.xkb.rules -->
## `programs.niri.settings.input.keyboard.xkb.rules`
- type: `string`
- default: `""`

The rules file to use.

The rules file describes how to interpret the values of the model, layout, variant and options fields.

If this is set to an empty string, the rules will be read from the `XKB_DEFAULT_RULES` environment variable.



<!-- sorting key: programs.niri.settings.f.input.keyboard.xkb.variant -->
## `programs.niri.settings.input.keyboard.xkb.variant`
- type: `string`
- default: `""`

A comma separated list of variants, one per layout, which may modify or augment the respective layout in various ways.

See [`xkeyboard-config(7)`](https://man.archlinux.org/man/xkeyboard-config.7#LAYOUTS) for a list of available variants for each layout.

If this is set to an empty string, the variant will be read from the `XKB_DEFAULT_VARIANT` environment variable.



<!-- sorting key: programs.niri.settings.f.input.mouse.accel-profile -->
## `programs.niri.settings.input.mouse.accel-profile`
- type: `null or one of "adaptive", "flat"`
- default: `null`

Further reading:
- https://wayland.freedesktop.org/libinput/doc/latest/pointer-acceleration.html#pointer-acceleration-profiles


<!-- sorting key: programs.niri.settings.f.input.mouse.accel-speed -->
## `programs.niri.settings.input.mouse.accel-speed`
- type: `floating point number`
- default: `0.000000`

Further reading:
- https://wayland.freedesktop.org/libinput/doc/latest/configuration.html#pointer-acceleration


<!-- sorting key: programs.niri.settings.f.input.mouse.natural-scroll -->
## `programs.niri.settings.input.mouse.natural-scroll`
- type: `boolean`
- default: `false`

Whether scrolling should move the content in the scrolled direction (as opposed to moving the viewport)

Further reading:
- https://wayland.freedesktop.org/libinput/doc/latest/configuration.html#scrolling
- https://wayland.freedesktop.org/libinput/doc/latest/scrolling.html#natural-scrolling-vs-traditional-scrolling


<!-- sorting key: programs.niri.settings.f.input.power-key-handling.enable -->
## `programs.niri.settings.input.power-key-handling.enable`
- type: `boolean`
- default: `true`

By default, niri will take over the power button to make it sleep instead of power off.

You can disable this behaviour if you prefer to configure the power button elsewhere.


<!-- sorting key: programs.niri.settings.f.input.tablet.map-to-output -->
## `programs.niri.settings.input.tablet.map-to-output`
- type: `null or string`
- default: `null`


<!-- sorting key: programs.niri.settings.f.input.touch.map-to-output -->
## `programs.niri.settings.input.touch.map-to-output`
- type: `null or string`
- default: `null`


<!-- sorting key: programs.niri.settings.f.input.touchpad.accel-profile -->
## `programs.niri.settings.input.touchpad.accel-profile`
- type: `null or one of "adaptive", "flat"`
- default: `null`

Further reading:
- https://wayland.freedesktop.org/libinput/doc/latest/pointer-acceleration.html#pointer-acceleration-profiles


<!-- sorting key: programs.niri.settings.f.input.touchpad.accel-speed -->
## `programs.niri.settings.input.touchpad.accel-speed`
- type: `floating point number`
- default: `0.000000`

Further reading:
- https://wayland.freedesktop.org/libinput/doc/latest/configuration.html#pointer-acceleration


<!-- sorting key: programs.niri.settings.f.input.touchpad.click-method -->
## `programs.niri.settings.input.touchpad.click-method`
- type: `null or one of "button-areas", "clickfinger"`
- default: `null`

> [!important]
> This option is not yet available in stable niri.
>
> If you wish to modify this option, you should make sure [`programs.niri.package`](#programsniripackage) is set to [`pkgs.niri-unstable`](#packagessystemniri-unstable).
>
> Otherwise, your system might fail to build.


Method to determine which mouse button is pressed when you click the touchpad.

- `"button-areas"`: [Software button areas](https://wayland.freedesktop.org/libinput/doc/latest/clickpad-softbuttons.html.html#software-button-areas) \
  The button is determined by which part of the touchpad was clicked.

- `"clickfinger"`: [Clickfinger behavior](https://wayland.freedesktop.org/libinput/doc/latest/clickpad-softbuttons.html.html#clickfinger-behavior) \
  The button is determined by how many fingers clicked.

Further reading:
- https://wayland.freedesktop.org/libinput/doc/latest/configuration.html#click-method
- https://wayland.freedesktop.org/libinput/doc/latest/clickpad-softbuttons.html#clickpad-software-button-behavior


<!-- sorting key: programs.niri.settings.f.input.touchpad.dwt -->
## `programs.niri.settings.input.touchpad.dwt`
- type: `boolean`
- default: `false`

Whether to disable the touchpad while typing.

Further reading:
- https://wayland.freedesktop.org/libinput/doc/latest/configuration.html#disable-while-typing
- https://wayland.freedesktop.org/libinput/doc/latest/palm-detection.html#disable-while-typing


<!-- sorting key: programs.niri.settings.f.input.touchpad.dwtp -->
## `programs.niri.settings.input.touchpad.dwtp`
- type: `boolean`
- default: `false`

Whether to disable the touchpad while the trackpoint is in use.

Further reading:
- https://wayland.freedesktop.org/libinput/doc/latest/configuration.html#disable-while-trackpointing
- https://wayland.freedesktop.org/libinput/doc/latest/palm-detection.html#disable-while-trackpointing


<!-- sorting key: programs.niri.settings.f.input.touchpad.natural-scroll -->
## `programs.niri.settings.input.touchpad.natural-scroll`
- type: `boolean`
- default: `true`

Whether scrolling should move the content in the scrolled direction (as opposed to moving the viewport)

Further reading:
- https://wayland.freedesktop.org/libinput/doc/latest/configuration.html#scrolling
- https://wayland.freedesktop.org/libinput/doc/latest/scrolling.html#natural-scrolling-vs-traditional-scrolling


<!-- sorting key: programs.niri.settings.f.input.touchpad.tap -->
## `programs.niri.settings.input.touchpad.tap`
- type: `boolean`
- default: `true`

Whether to enable tap-to-click.

Further reading:
- https://wayland.freedesktop.org/libinput/doc/latest/configuration.html#tap-to-click
- https://wayland.freedesktop.org/libinput/doc/latest/tapping.html#tap-to-click-behaviour


<!-- sorting key: programs.niri.settings.f.input.touchpad.tap-button-map -->
## `programs.niri.settings.input.touchpad.tap-button-map`
- type: `null or one of "left-middle-right", "left-right-middle"`
- default: `null`

The mouse button to register when tapping with 1, 2, or 3 fingers, when [`input.touchpad.tap`](#programsnirisettingsinputtouchpadtap) is enabled.

Further reading:
- https://wayland.freedesktop.org/libinput/doc/latest/configuration.html#tap-to-click


<!-- sorting key: programs.niri.settings.f.input.trackpoint.accel-profile -->
## `programs.niri.settings.input.trackpoint.accel-profile`
- type: `null or one of "adaptive", "flat"`
- default: `null`

Further reading:
- https://wayland.freedesktop.org/libinput/doc/latest/pointer-acceleration.html#pointer-acceleration-profiles


<!-- sorting key: programs.niri.settings.f.input.trackpoint.accel-speed -->
## `programs.niri.settings.input.trackpoint.accel-speed`
- type: `floating point number`
- default: `0.000000`

Further reading:
- https://wayland.freedesktop.org/libinput/doc/latest/configuration.html#pointer-acceleration


<!-- sorting key: programs.niri.settings.f.input.trackpoint.natural-scroll -->
## `programs.niri.settings.input.trackpoint.natural-scroll`
- type: `boolean`
- default: `false`

Whether scrolling should move the content in the scrolled direction (as opposed to moving the viewport)

Further reading:
- https://wayland.freedesktop.org/libinput/doc/latest/configuration.html#scrolling
- https://wayland.freedesktop.org/libinput/doc/latest/scrolling.html#natural-scrolling-vs-traditional-scrolling


<!-- sorting key: programs.niri.settings.f.input.warp-mouse-to-focus -->
## `programs.niri.settings.input.warp-mouse-to-focus`
- type: `boolean`
- default: `false`

> [!important]
> This option is not yet available in stable niri.
>
> If you wish to modify this option, you should make sure [`programs.niri.package`](#programsniripackage) is set to [`pkgs.niri-unstable`](#packagessystemniri-unstable).
>
> Otherwise, your system might fail to build.


Whether to warp the mouse to the focused window when switching focus.


<!-- sorting key: programs.niri.settings.f.input.workspace-auto-back-and-forth -->
## `programs.niri.settings.input.workspace-auto-back-and-forth`
- type: `boolean`
- default: `false`

> [!important]
> This option is not yet available in stable niri.
>
> If you wish to modify this option, you should make sure [`programs.niri.package`](#programsniripackage) is set to [`pkgs.niri-unstable`](#packagessystemniri-unstable).
>
> Otherwise, your system might fail to build.


When invoking `focus-workspace` to switch to a workspace by index, if the workspace is already focused, usually nothing happens. When this option is enabled, the workspace will cycle back to the previously active workspace.

Of note is that it does not switch to the previous *index*, but the previous *workspace*. That means you can reorder workspaces inbetween these actions, and it will still take you to the actual same workspace you came from.


<!-- sorting key: programs.niri.settings.g.outputs -->
## `programs.niri.settings.outputs`
- type: `attribute set of (submodule)`


<!-- sorting key: programs.niri.settings.g.outputs.enable -->
## `programs.niri.settings.outputs.<name>.enable`
- type: `boolean`
- default: `true`


<!-- sorting key: programs.niri.settings.g.outputs.mode -->
## `programs.niri.settings.outputs.<name>.mode`
- type: `null or (submodule)`
- default: `null`

The resolution and refresh rate of this display.

By default, when this is null, niri will automatically pick a mode for you.

If this is set to an invalid mode (i.e unsupported by this output), niri will act as if it is unset and pick one for you.


<!-- sorting key: programs.niri.settings.g.outputs.mode.height -->
## `programs.niri.settings.outputs.<name>.mode.height`
- type: `signed integer`


<!-- sorting key: programs.niri.settings.g.outputs.mode.refresh -->
## `programs.niri.settings.outputs.<name>.mode.refresh`
- type: `null or floating point number`
- default: `null`

The refresh rate of this output. When this is null, but the resolution is set, niri will automatically pick the highest available refresh rate.


<!-- sorting key: programs.niri.settings.g.outputs.mode.width -->
## `programs.niri.settings.outputs.<name>.mode.width`
- type: `signed integer`


<!-- sorting key: programs.niri.settings.g.outputs.position -->
## `programs.niri.settings.outputs.<name>.position`
- type: `null or (submodule)`
- default: `null`

Position of the output in the global coordinate space.

This affects directional monitor actions like "focus-monitor-left", and cursor movement.

The cursor can only move between directly adjacent outputs.

Output scale has to be taken into account for positioning, because outputs are sized in logical pixels.

For example, a 3840x2160 output with scale 2.0 will have a logical size of 1920x1080, so to put another output directly adjacent to it on the right, set its x to 1920.

If the position is unset or multiple outputs overlap, niri will instead place the output automatically.


<!-- sorting key: programs.niri.settings.g.outputs.position.x -->
## `programs.niri.settings.outputs.<name>.position.x`
- type: `signed integer`


<!-- sorting key: programs.niri.settings.g.outputs.position.y -->
## `programs.niri.settings.outputs.<name>.position.y`
- type: `signed integer`


<!-- sorting key: programs.niri.settings.g.outputs.scale -->
## `programs.niri.settings.outputs.<name>.scale`
- type: `floating point number`
- default: `1.000000`

The scale of this output, which represents how many physical pixels fit in one logical pixel.

Although this is a floating-point number, niri currently only accepts integer values. It does not support fractional scaling.


<!-- sorting key: programs.niri.settings.g.outputs.transform.flipped -->
## `programs.niri.settings.outputs.<name>.transform.flipped`
- type: `boolean`
- default: `false`

Whether to flip this output vertically.


<!-- sorting key: programs.niri.settings.g.outputs.transform.rotation -->
## `programs.niri.settings.outputs.<name>.transform.rotation`
- type: `one of 0, 90, 180, 270`
- default: `0`

Counter-clockwise rotation of this output in degrees.


<!-- sorting key: programs.niri.settings.h.cursor.size -->
## `programs.niri.settings.cursor.size`
- type: `signed integer`
- default: `24`

The size of the cursor in logical pixels.

This will also set the XCURSOR_SIZE environment variable for all spawned processes.


<!-- sorting key: programs.niri.settings.h.cursor.theme -->
## `programs.niri.settings.cursor.theme`
- type: `string`
- default: `"default"`

The name of the xcursor theme to use.

This will also set the XCURSOR_THEME environment variable for all spawned processes.


<!-- sorting key: programs.niri.settings.i.layout.border -->
## `programs.niri.settings.layout.border`


The border is a decoration drawn *inside* every window in the layout. It will take space away from windows. That is, if you have a border of 8px, then each window will be 8px smaller on each edge than if you had no border.

The currently focused window, i.e. the window that can receive keyboard input, will be drawn according to [`layout.border.active`](#programsnirisettingslayoutborderactive), and all other windows will be drawn according to [`layout.border.inactive`](#programsnirisettingslayoutborderinactive).

If you have [`layout.focus-ring`](#programsnirisettingslayoutfocus-ring) enabled, the border will be drawn inside (and over) the focus ring.


<!-- sorting key: programs.niri.settings.i.layout.border.active -->
## `programs.niri.settings.layout.border.active`
- type: `variant of: color | gradient`
- default:
  ```nix
  {
    color = "rgb(255 200 127)";
  }
  ```


The color of the border for the window that has keyboard focus.


<!-- sorting key: programs.niri.settings.i.layout.border.active.color -->
## `programs.niri.settings.layout.border.active.color`
- type: `string`

A solid color to use for the decoration.

This is a CSS [`<color>`](https://developer.mozilla.org/en-US/docs/Web/CSS/color_value) value, like `"rgb(255 0 0)"`, `"#C0FFEE"`, or `"sandybrown"`.

The specific crate that niri uses to parse this also supports some nonstandard color functions, like `hwba()`, `hsv()`, `hsva()`. See [`csscolorparser`](https://crates.io/crates/csscolorparser) for details.


<!-- sorting key: programs.niri.settings.i.layout.border.active.gradient -->
## `programs.niri.settings.layout.border.active.gradient`
- type: `gradient`

A linear gradient to use for the decoration.

This is meant to approximate the CSS [`linear-gradient()`](https://developer.mozilla.org/en-US/docs/Web/CSS/gradient/linear-gradient) function, but niri does not fully support all the same parameters. Only an angle in degrees is supported.


<!-- sorting key: programs.niri.settings.i.layout.border.active.gradient.angle -->
## `programs.niri.settings.layout.border.active.gradient.angle`
- type: `signed integer`
- default: `180`

The angle of the gradient, in degrees, measured clockwise from a gradient that starts at the bottom and ends at the top.

This is the same as the angle parameter in the CSS [`linear-gradient()`](https://developer.mozilla.org/en-US/docs/Web/CSS/gradient/linear-gradient) function, except you can only express it in degrees.


<!-- sorting key: programs.niri.settings.i.layout.border.active.gradient.from -->
## `programs.niri.settings.layout.border.active.gradient.from`
- type: `string`

The starting [`<color>`](https://developer.mozilla.org/en-US/docs/Web/CSS/color_value) of the gradient.

For more details, see [`layout.border.active.color`](#programsnirisettingslayoutborderactivecolor).


<!-- sorting key: programs.niri.settings.i.layout.border.active.gradient.relative-to -->
## `programs.niri.settings.layout.border.active.gradient.relative-to`
- type: `one of "window", "workspace-view"`
- default: `"window"`

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

these beautiful images are sourced from the release notes for [`v0.1.3`](https://github.com/YaLTeR/niri/releases/tag/v0.1.3)


<!-- sorting key: programs.niri.settings.i.layout.border.active.gradient.to -->
## `programs.niri.settings.layout.border.active.gradient.to`
- type: `string`

The ending [`<color>`](https://developer.mozilla.org/en-US/docs/Web/CSS/color_value) of the gradient.

For more details, see [`layout.border.active.color`](#programsnirisettingslayoutborderactivecolor).


<!-- sorting key: programs.niri.settings.i.layout.border.enable -->
## `programs.niri.settings.layout.border.enable`
- type: `boolean`
- default: `false`

Whether to enable the border.


<!-- sorting key: programs.niri.settings.i.layout.border.inactive -->
## `programs.niri.settings.layout.border.inactive`
- type: `variant of: color | gradient`
- default:
  ```nix
  {
    color = "rgb(80 80 80)";
  }
  ```


The color of the border for windows that do not have keyboard focus.


<!-- sorting key: programs.niri.settings.i.layout.border.inactive.color -->
## `programs.niri.settings.layout.border.inactive.color`
- type: `string`

A solid color to use for the decoration.

This is a CSS [`<color>`](https://developer.mozilla.org/en-US/docs/Web/CSS/color_value) value, like `"rgb(255 0 0)"`, `"#C0FFEE"`, or `"sandybrown"`.

The specific crate that niri uses to parse this also supports some nonstandard color functions, like `hwba()`, `hsv()`, `hsva()`. See [`csscolorparser`](https://crates.io/crates/csscolorparser) for details.


<!-- sorting key: programs.niri.settings.i.layout.border.inactive.gradient -->
## `programs.niri.settings.layout.border.inactive.gradient`
- type: `gradient`

A linear gradient to use for the decoration.

This is meant to approximate the CSS [`linear-gradient()`](https://developer.mozilla.org/en-US/docs/Web/CSS/gradient/linear-gradient) function, but niri does not fully support all the same parameters. Only an angle in degrees is supported.


<!-- sorting key: programs.niri.settings.i.layout.border.inactive.gradient.angle -->
## `programs.niri.settings.layout.border.inactive.gradient.angle`
- type: `signed integer`
- default: `180`

The angle of the gradient, in degrees, measured clockwise from a gradient that starts at the bottom and ends at the top.

This is the same as the angle parameter in the CSS [`linear-gradient()`](https://developer.mozilla.org/en-US/docs/Web/CSS/gradient/linear-gradient) function, except you can only express it in degrees.


<!-- sorting key: programs.niri.settings.i.layout.border.inactive.gradient.from -->
## `programs.niri.settings.layout.border.inactive.gradient.from`
- type: `string`

The starting [`<color>`](https://developer.mozilla.org/en-US/docs/Web/CSS/color_value) of the gradient.

For more details, see [`layout.border.inactive.color`](#programsnirisettingslayoutborderinactivecolor).


<!-- sorting key: programs.niri.settings.i.layout.border.inactive.gradient.relative-to -->
## `programs.niri.settings.layout.border.inactive.gradient.relative-to`
- type: `one of "window", "workspace-view"`
- default: `"window"`

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

these beautiful images are sourced from the release notes for [`v0.1.3`](https://github.com/YaLTeR/niri/releases/tag/v0.1.3)


<!-- sorting key: programs.niri.settings.i.layout.border.inactive.gradient.to -->
## `programs.niri.settings.layout.border.inactive.gradient.to`
- type: `string`

The ending [`<color>`](https://developer.mozilla.org/en-US/docs/Web/CSS/color_value) of the gradient.

For more details, see [`layout.border.inactive.color`](#programsnirisettingslayoutborderinactivecolor).


<!-- sorting key: programs.niri.settings.i.layout.border.width -->
## `programs.niri.settings.layout.border.width`
- type: `signed integer`
- default: `4`

The width of the border drawn around each window.


<!-- sorting key: programs.niri.settings.i.layout.center-focused-column -->
## `programs.niri.settings.layout.center-focused-column`
- type: `one of "never", "always", "on-overflow"`
- default: `"never"`

When changing focus, niri can automatically center the focused column.

- `"never"`: If the focused column doesn't fit, it will be aligned to the edges of the screen.
- `"on-overflow"`: if the focused column doesn't fit, it will be centered on the screen.
- `"always"`: the focused column will always be centered, even if it was already fully visible.


<!-- sorting key: programs.niri.settings.i.layout.default-column-width -->
## `programs.niri.settings.layout.default-column-width`
- type: `{} or (variant of: fixed | proportion)`

The default width for new columns.

When this is set to an empty attrset `{}`, windows will get to decide their initial width. This is not null, such that it can be distinguished from window rules that don't touch this

See [`layout.preset-column-widths`](#programsnirisettingslayoutpreset-column-widths) for more information.

You can override this for specific windows using [`window-rules.*.default-column-width`](#programsnirisettingswindow-rulesdefault-column-width)


<!-- sorting key: programs.niri.settings.i.layout.default-column-width.fixed -->
## `programs.niri.settings.layout.default-column-width.fixed`
- type: `signed integer`

The width of the column in logical pixels


<!-- sorting key: programs.niri.settings.i.layout.default-column-width.proportion -->
## `programs.niri.settings.layout.default-column-width.proportion`
- type: `floating point number`

The width of the column as a proportion of the screen's width


<!-- sorting key: programs.niri.settings.i.layout.focus-ring -->
## `programs.niri.settings.layout.focus-ring`


The focus ring is a decoration drawn *around* the last focused window on each monitor. It takes no space away from windows. If you have insufficient gaps, the focus ring can be drawn over adjacent windows, but it will never affect the layout of windows.

The focused window of the currently focused monitor, i.e. the window that can receive keyboard input, will be drawn according to [`layout.focus-ring.active`](#programsnirisettingslayoutfocus-ringactive), and the last focused window on all other monitors will be drawn according to [`layout.focus-ring.inactive`](#programsnirisettingslayoutfocus-ringinactive).

If you have [`layout.border`](#programsnirisettingslayoutborder) enabled, the focus ring will be drawn around (and under) the border.


<!-- sorting key: programs.niri.settings.i.layout.focus-ring.active -->
## `programs.niri.settings.layout.focus-ring.active`
- type: `variant of: color | gradient`
- default:
  ```nix
  {
    color = "rgb(127 200 255)";
  }
  ```


The color of the focus ring for the window that has keyboard focus.


<!-- sorting key: programs.niri.settings.i.layout.focus-ring.active.color -->
## `programs.niri.settings.layout.focus-ring.active.color`
- type: `string`

A solid color to use for the decoration.

This is a CSS [`<color>`](https://developer.mozilla.org/en-US/docs/Web/CSS/color_value) value, like `"rgb(255 0 0)"`, `"#C0FFEE"`, or `"sandybrown"`.

The specific crate that niri uses to parse this also supports some nonstandard color functions, like `hwba()`, `hsv()`, `hsva()`. See [`csscolorparser`](https://crates.io/crates/csscolorparser) for details.


<!-- sorting key: programs.niri.settings.i.layout.focus-ring.active.gradient -->
## `programs.niri.settings.layout.focus-ring.active.gradient`
- type: `gradient`

A linear gradient to use for the decoration.

This is meant to approximate the CSS [`linear-gradient()`](https://developer.mozilla.org/en-US/docs/Web/CSS/gradient/linear-gradient) function, but niri does not fully support all the same parameters. Only an angle in degrees is supported.


<!-- sorting key: programs.niri.settings.i.layout.focus-ring.active.gradient.angle -->
## `programs.niri.settings.layout.focus-ring.active.gradient.angle`
- type: `signed integer`
- default: `180`

The angle of the gradient, in degrees, measured clockwise from a gradient that starts at the bottom and ends at the top.

This is the same as the angle parameter in the CSS [`linear-gradient()`](https://developer.mozilla.org/en-US/docs/Web/CSS/gradient/linear-gradient) function, except you can only express it in degrees.


<!-- sorting key: programs.niri.settings.i.layout.focus-ring.active.gradient.from -->
## `programs.niri.settings.layout.focus-ring.active.gradient.from`
- type: `string`

The starting [`<color>`](https://developer.mozilla.org/en-US/docs/Web/CSS/color_value) of the gradient.

For more details, see [`layout.focus-ring.active.color`](#programsnirisettingslayoutfocus-ringactivecolor).


<!-- sorting key: programs.niri.settings.i.layout.focus-ring.active.gradient.relative-to -->
## `programs.niri.settings.layout.focus-ring.active.gradient.relative-to`
- type: `one of "window", "workspace-view"`
- default: `"window"`

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

these beautiful images are sourced from the release notes for [`v0.1.3`](https://github.com/YaLTeR/niri/releases/tag/v0.1.3)


<!-- sorting key: programs.niri.settings.i.layout.focus-ring.active.gradient.to -->
## `programs.niri.settings.layout.focus-ring.active.gradient.to`
- type: `string`

The ending [`<color>`](https://developer.mozilla.org/en-US/docs/Web/CSS/color_value) of the gradient.

For more details, see [`layout.focus-ring.active.color`](#programsnirisettingslayoutfocus-ringactivecolor).


<!-- sorting key: programs.niri.settings.i.layout.focus-ring.enable -->
## `programs.niri.settings.layout.focus-ring.enable`
- type: `boolean`
- default: `true`

Whether to enable the focus ring.


<!-- sorting key: programs.niri.settings.i.layout.focus-ring.inactive -->
## `programs.niri.settings.layout.focus-ring.inactive`
- type: `variant of: color | gradient`
- default:
  ```nix
  {
    color = "rgb(80 80 80)";
  }
  ```


The color of the focus ring for windows that do not have keyboard focus.


<!-- sorting key: programs.niri.settings.i.layout.focus-ring.inactive.color -->
## `programs.niri.settings.layout.focus-ring.inactive.color`
- type: `string`

A solid color to use for the decoration.

This is a CSS [`<color>`](https://developer.mozilla.org/en-US/docs/Web/CSS/color_value) value, like `"rgb(255 0 0)"`, `"#C0FFEE"`, or `"sandybrown"`.

The specific crate that niri uses to parse this also supports some nonstandard color functions, like `hwba()`, `hsv()`, `hsva()`. See [`csscolorparser`](https://crates.io/crates/csscolorparser) for details.


<!-- sorting key: programs.niri.settings.i.layout.focus-ring.inactive.gradient -->
## `programs.niri.settings.layout.focus-ring.inactive.gradient`
- type: `gradient`

A linear gradient to use for the decoration.

This is meant to approximate the CSS [`linear-gradient()`](https://developer.mozilla.org/en-US/docs/Web/CSS/gradient/linear-gradient) function, but niri does not fully support all the same parameters. Only an angle in degrees is supported.


<!-- sorting key: programs.niri.settings.i.layout.focus-ring.inactive.gradient.angle -->
## `programs.niri.settings.layout.focus-ring.inactive.gradient.angle`
- type: `signed integer`
- default: `180`

The angle of the gradient, in degrees, measured clockwise from a gradient that starts at the bottom and ends at the top.

This is the same as the angle parameter in the CSS [`linear-gradient()`](https://developer.mozilla.org/en-US/docs/Web/CSS/gradient/linear-gradient) function, except you can only express it in degrees.


<!-- sorting key: programs.niri.settings.i.layout.focus-ring.inactive.gradient.from -->
## `programs.niri.settings.layout.focus-ring.inactive.gradient.from`
- type: `string`

The starting [`<color>`](https://developer.mozilla.org/en-US/docs/Web/CSS/color_value) of the gradient.

For more details, see [`layout.focus-ring.inactive.color`](#programsnirisettingslayoutfocus-ringinactivecolor).


<!-- sorting key: programs.niri.settings.i.layout.focus-ring.inactive.gradient.relative-to -->
## `programs.niri.settings.layout.focus-ring.inactive.gradient.relative-to`
- type: `one of "window", "workspace-view"`
- default: `"window"`

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

these beautiful images are sourced from the release notes for [`v0.1.3`](https://github.com/YaLTeR/niri/releases/tag/v0.1.3)


<!-- sorting key: programs.niri.settings.i.layout.focus-ring.inactive.gradient.to -->
## `programs.niri.settings.layout.focus-ring.inactive.gradient.to`
- type: `string`

The ending [`<color>`](https://developer.mozilla.org/en-US/docs/Web/CSS/color_value) of the gradient.

For more details, see [`layout.focus-ring.inactive.color`](#programsnirisettingslayoutfocus-ringinactivecolor).


<!-- sorting key: programs.niri.settings.i.layout.focus-ring.width -->
## `programs.niri.settings.layout.focus-ring.width`
- type: `signed integer`
- default: `4`

The width of the focus ring drawn around each focused window.


<!-- sorting key: programs.niri.settings.i.layout.gaps -->
## `programs.niri.settings.layout.gaps`
- type: `signed integer`
- default: `16`

The gap between windows in the layout, measured in logical pixels.


<!-- sorting key: programs.niri.settings.i.layout.preset-column-widths -->
## `programs.niri.settings.layout.preset-column-widths`
- type: `list of variant of: fixed | proportion`

The widths that `switch-preset-column-width` will cycle through.

Each width can either be a fixed width in logical pixels, or a proportion of the screen's width.

Example:

```nix
{
  programs.niri.settings.layout.preset-coumn-widths = [
    { proportion = 1./3.; }
    { proportion = 1./2.; }
    { proportion = 2./3.; }

    # { fixed = 1920; }
  ];
}
```


<!-- sorting key: programs.niri.settings.i.layout.preset-column-widths.fixed -->
## `programs.niri.settings.layout.preset-column-widths.*.fixed`
- type: `signed integer`

The width of the column in logical pixels


<!-- sorting key: programs.niri.settings.i.layout.preset-column-widths.proportion -->
## `programs.niri.settings.layout.preset-column-widths.*.proportion`
- type: `floating point number`

The width of the column as a proportion of the screen's width


<!-- sorting key: programs.niri.settings.i.layout.struts -->
## `programs.niri.settings.layout.struts`


The distances from the edges of the screen to the eges of the working area.

The top and bottom struts are absolute gaps from the edges of the screen. If you set a bottom strut of 64px and the scale is 2.0, then the output will have 128 physical pixels under the scrollable working area where it only shows the wallpaper.

Struts are computed in addition to layer-shell surfaces. If you have a waybar of 32px at the top, and you set a top strut of 16px, then you will have 48 logical pixels from the actual edge of the display to the top of the working area.

The left and right structs work in a similar way, except the padded space is not empty. The horizontal struts are used to constrain where focused windows are allowed to go. If you define a left strut of 64px and go to the first window in a workspace, that window will be aligned 64 logical pixels from the left edge of the output, rather than snapping to the actual edge of the screen. If another window exists to the left of this window, then you will see 64px of its right edge (if you have zero borders and gaps)


<!-- sorting key: programs.niri.settings.i.layout.struts.bottom -->
## `programs.niri.settings.layout.struts.bottom`
- type: `signed integer`
- default: `0`


<!-- sorting key: programs.niri.settings.i.layout.struts.left -->
## `programs.niri.settings.layout.struts.left`
- type: `signed integer`
- default: `0`


<!-- sorting key: programs.niri.settings.i.layout.struts.right -->
## `programs.niri.settings.layout.struts.right`
- type: `signed integer`
- default: `0`


<!-- sorting key: programs.niri.settings.i.layout.struts.top -->
## `programs.niri.settings.layout.struts.top`
- type: `signed integer`
- default: `0`


<!-- sorting key: programs.niri.settings.j.animations -->
## `programs.niri.settings.animations`
- type: `animations`


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
## `programs.niri.settings.animations.<name>.easing`



<!-- sorting key: programs.niri.settings.j.animations.b.submodule.easing.curve -->
## `programs.niri.settings.animations.<name>.easing.curve`
- type: `one of "ease-out-cubic", "ease-out-expo"`


<!-- sorting key: programs.niri.settings.j.animations.b.submodule.easing.duration-ms -->
## `programs.niri.settings.animations.<name>.easing.duration-ms`
- type: `signed integer`


<!-- sorting key: programs.niri.settings.j.animations.b.submodule.spring -->
## `programs.niri.settings.animations.<name>.spring`



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
- type: `list of window rule`

Window rules.

A window rule will match based on [`window-rules.*.matches`](#programsnirisettingswindow-rulesmatches) and [`window-rules.*.excludes`](#programsnirisettingswindow-rulesexcludes). Both of these are lists of "match rules".

A given match rule can match based on the `title` or `app-id` fields. For a given match rule to "match" a window, it must match on all fields.

- The `title` field, when non-null, is a regular expression. It will match a window if the client has set a title and its title matches the regular expression.

- The `app-id` field, when non-null, is a regular expression. It will match a window if the client has set an app id and its app id matches the regular expression.

- If a field is null, it will always match.

For a given window rule to match a window, the above logic is employed to determine whether any given match rule matches, and the interactions between them decide whether the window rule as a whole will match. For a given window rule:

- A given window is "considered" if any of the match rules in [`window-rules.*.matches`](#programsnirisettingswindow-rulesmatches) successfully match this window. If all of the match rules do not match this window, then that window will never match this window rule.

- If [`window-rules.*.matches`](#programsnirisettingswindow-rulesmatches) contains no match rules, it will match any window and "consider" it for this window rule.

- If a given window is "considered" for this window rule according to the above rules, the selection can be further refined with [`window-rules.*.excludes`](#programsnirisettingswindow-rulesexcludes). If any of the match rules in `excludes` match this window, it will be rejected and this window rule will not match the given window.

That is, a given window rule will apply to a given window if any of the entries in [`window-rules.*.matches`](#programsnirisettingswindow-rulesmatches) match that window (or there are none), AND none of the entries in [`window-rules.*.excludes`](#programsnirisettingswindow-rulesexcludes) match that window.

All fields of a window rule can be set to null, which represents that the field shall have no effect on the window (and in general, the client is allowed to choose the initial value).

To compute the final set of window rules that apply to a given window, each window rule in this list is consdered in order.

At first, every field is set to null.

Then, for each applicable window rule:

- If a given field is null on this window rule, it has no effect. It does nothing and "inherits" the value from the previous rule.
- If the given field is not null, it will overwrite the value from any previous rule.

The "final value" of a field is simply its value at the end of this process. That is, the final value of a field is the one from the *last* window rule that matches the given window rule (not considering null entries, unless there are no non-null entries)

If the final value of a given field is null, then it usually means that the client gets to decide. For more information, see the documentation for each field.


<!-- sorting key: programs.niri.settings.l.window-rules.a.matches -->
## `programs.niri.settings.window-rules.*.matches`
- type: `list of match rule`

A list of rules to match windows.

If any of these rules match a window (or there are none), that window rule will be considered for this window. It can still be rejected by [`window-rules.*.excludes`](#programsnirisettingswindow-rulesexcludes)

If all of the rules do not match a window, then this window rule will not apply to that window.


<!-- sorting key: programs.niri.settings.l.window-rules.a.matches.app-id -->
## `programs.niri.settings.window-rules.*.matches.*.app-id`
- type: `null or string`
- default: `null`


<!-- sorting key: programs.niri.settings.l.window-rules.a.matches.title -->
## `programs.niri.settings.window-rules.*.matches.*.title`
- type: `null or string`
- default: `null`


<!-- sorting key: programs.niri.settings.l.window-rules.b.excludes -->
## `programs.niri.settings.window-rules.*.excludes`
- type: `list of match rule`

A list of rules to exclude windows.

If any of these rules match a window, then this window rule will not apply to that window, even if it matches one of the rules in [`window-rules.*.matches`](#programsnirisettingswindow-rulesmatches)

If none of these rules match a window, then this window rule will not be rejected. It will apply to that window if and only if it matches one of the rules in [`window-rules.*.matches`](#programsnirisettingswindow-rulesmatches)


<!-- sorting key: programs.niri.settings.l.window-rules.b.excludes.app-id -->
## `programs.niri.settings.window-rules.*.excludes.*.app-id`
- type: `null or string`
- default: `null`


<!-- sorting key: programs.niri.settings.l.window-rules.b.excludes.title -->
## `programs.niri.settings.window-rules.*.excludes.*.title`
- type: `null or string`
- default: `null`


<!-- sorting key: programs.niri.settings.l.window-rules.c.default-column-width -->
## `programs.niri.settings.window-rules.*.default-column-width`
- type: `null or {} or (variant of: fixed | proportion)`
- default: `null`

By default, when this option is null, then this window rule will not affect the default column width. If none of the applicable window rules have a nonnull value, it will be gotten from [`layout.default-column-width`](#programsnirisettingslayoutdefault-column-width)

If this option is not null, then its value will take priority over [`layout.default-column-width`](#programsnirisettingslayoutdefault-column-width) for windows matching this rule.

As a reminder, an empty attrset `{}` is not the same as null. Here, null represents that this window rule has no effect on the default width, wheras `{}` represents "let the client choose".


<!-- sorting key: programs.niri.settings.l.window-rules.c.default-column-width.fixed -->
## `programs.niri.settings.window-rules.*.default-column-width.fixed`
- type: `signed integer`

The width of the column in logical pixels


<!-- sorting key: programs.niri.settings.l.window-rules.c.default-column-width.proportion -->
## `programs.niri.settings.window-rules.*.default-column-width.proportion`
- type: `floating point number`

The width of the column as a proportion of the screen's width


<!-- sorting key: programs.niri.settings.l.window-rules.c.open-fullscreen -->
## `programs.niri.settings.window-rules.*.open-fullscreen`
- type: `null or boolean`
- default: `null`

Whether to open this window in fullscreen.

If the final value of this field is true, then this window will always be forced to open in fullscreen.

If the final value of this field is false, then this window is never allowed to open in fullscreen, even if it requests to do so.

If the final value of this field is null, then the client gets to decide if this window will open in fullscreen.


<!-- sorting key: programs.niri.settings.l.window-rules.c.open-maximized -->
## `programs.niri.settings.window-rules.*.open-maximized`
- type: `null or boolean`
- default: `null`

Whether to open this window in a maximized column.

If the final value of this field is null or false, then the window will not open in a maximized column.

If the final value of this field is true, then the window will open in a maximized column.


<!-- sorting key: programs.niri.settings.l.window-rules.c.open-on-output -->
## `programs.niri.settings.window-rules.*.open-on-output`
- type: `null or string`
- default: `null`

The output to open this window on.

If final value of this field is an output that exists, the new window will open on that output.

If the final value is an output that does not exist, or it is null, then the window opens on the currently focused output.


<!-- sorting key: programs.niri.settings.l.window-rules.d.draw-border-with-background -->
## `programs.niri.settings.window-rules.*.draw-border-with-background`
- type: `null or boolean`
- default: `null`

Whether to draw the focus ring and border with a background.

Normally, for windows with server-side decorations, niri will draw an actual border around them, because it knows they will be rectangular.

Because client-side decorations can take on arbitrary shapes, most notably including rounded corners, niri cannot really know the "correct" place to put a border, so for such windows it will draw a solid rectangle behind them instead.

For most windows, this looks okay. At worst, you have some uneven/jagged borders, instead of a gaping hole in the region outside of the corner radius of the window but inside its bounds.

If you wish to make windows sucha s your terminal transparent, and they use CSD, this is very undesirable. Instead of showing your wallpaper, you'll get a solid rectangle.

You can set this option per window to override niri's default behaviour, and instruct it to omit the border background for CSD windows. You can also explicitly enable it for SSD windows.


<!-- sorting key: programs.niri.settings.l.window-rules.e.max-height -->
## `programs.niri.settings.window-rules.*.max-height`
- type: `null or signed integer`
- default: `null`

> [!important]
> This option is not yet available in stable niri.
>
> If you wish to modify this option, you should make sure [`programs.niri.package`](#programsniripackage) is set to [`pkgs.niri-unstable`](#packagessystemniri-unstable).
>
> Otherwise, your system might fail to build.


Sets the maximum height (in logical pixels) that niri will ever ask this window for.

Keep in mind that the window itself always has a final say in its size, and may not respect the maximum height set by this option.


Also, note that the maximum height is not taken into account when automatically sizing columns. That is, when a column is created normally, windows in it will be "automatically sized" to fill the vertical space. This algorithm will respect a minimum height, and not make windows any smaller than that, but the max height is only taken into account if it is equal to the min height. In other words, it will only accept a "fixed height" or a "minimum height". In practice, most windows do not set a max size unless it is equal to their min size, so this is usually not a problem without window rules.

If you manually change the window heights, then max-height will be taken into account and restrict you from making it any taller, as you'd intuitively expect.


<!-- sorting key: programs.niri.settings.l.window-rules.e.max-width -->
## `programs.niri.settings.window-rules.*.max-width`
- type: `null or signed integer`
- default: `null`

> [!important]
> This option is not yet available in stable niri.
>
> If you wish to modify this option, you should make sure [`programs.niri.package`](#programsniripackage) is set to [`pkgs.niri-unstable`](#packagessystemniri-unstable).
>
> Otherwise, your system might fail to build.


Sets the maximum width (in logical pixels) that niri will ever ask this window for.

Keep in mind that the window itself always has a final say in its size, and may not respect the maximum width set by this option.


<!-- sorting key: programs.niri.settings.l.window-rules.e.min-height -->
## `programs.niri.settings.window-rules.*.min-height`
- type: `null or signed integer`
- default: `null`

> [!important]
> This option is not yet available in stable niri.
>
> If you wish to modify this option, you should make sure [`programs.niri.package`](#programsniripackage) is set to [`pkgs.niri-unstable`](#packagessystemniri-unstable).
>
> Otherwise, your system might fail to build.


Sets the minimum height (in logical pixels) that niri will ever ask this window for.

Keep in mind that the window itself always has a final say in its size, and may not respect the minimum height set by this option.


<!-- sorting key: programs.niri.settings.l.window-rules.e.min-width -->
## `programs.niri.settings.window-rules.*.min-width`
- type: `null or signed integer`
- default: `null`

> [!important]
> This option is not yet available in stable niri.
>
> If you wish to modify this option, you should make sure [`programs.niri.package`](#programsniripackage) is set to [`pkgs.niri-unstable`](#packagessystemniri-unstable).
>
> Otherwise, your system might fail to build.


Sets the minimum width (in logical pixels) that niri will ever ask this window for.

Keep in mind that the window itself always has a final say in its size, and may not respect the minimum width set by this option.


<!-- sorting key: programs.niri.settings.m.debug -->
## `programs.niri.settings.debug`
- type: `null or (attribute set of kdl arguments)`
- default: `null`

Debug options for niri.

`kdl arguments` in the type refers to a list of arguments passed to a node under the `debug` section. This is a way to pass arbitrary KDL-valid data to niri. See [`binds`](#programsnirisettingsbinds) for more information on all the ways you can use this.

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

This option is, just like [`binds`](#programsnirisettingsbinds), not verified by the nix module. But, it will be validated by niri before committing the config.

Additionally, i don't guarantee stability of the debug options. They may change at any time without prior notice, either because of niri changing the available options, or because of me changing this to a more reasonable schema.
