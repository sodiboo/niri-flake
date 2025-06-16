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

Currently, this is release [`25.02`](https://github.com/YaLTeR/niri/releases/tag/25.02) with no additional patches.




To access this package under `pkgs.niri-stable`, you should use [`overlays.niri`](#overlaysniri).



<!-- sorting key: _.a.nonmodules.a.packages.niri-unstable -->
## `packages.<system>.niri-unstable`

The latest commit to the development branch of niri.

Currently, this is exactly commit [`da3dc91`](https://github.com/YaLTeR/niri/tree/da3dc913a60062343a5a76b8745e55173a150751) which was authored on `2025-06-16 11:59:08`.

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
- type: `attribute set of niri keybind`


<!-- sorting key: programs.niri.settings.a.binds.action -->
## `programs.niri.settings.binds.<name>.action`
- type: `niri action`, which is a `kdl leaf`

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
>     "Print".action = sh ''grim -g "$(slurp)" - | wl-copy'';
>   };
> }
> ```

- `λ screenshot-screen :: { write-to-disk :: bool }` (only on niri-stable)
- `λ move-window-to-workspace :: u8 | string` (only on niri-stable)
- `λ move-column-to-workspace :: u8 | string` (only on niri-stable)
- `λ quit :: { skip-confirmation :: bool }`
- `suspend`
- `power-off-monitors`
- `power-on-monitors`
- `toggle-debug-tint`
- `debug-toggle-opaque-regions`
- `debug-toggle-damage`
- `λ spawn :: [string]`
- `λ do-screen-transition :: { delay-ms? :: u16 }`
- `λ screenshot :: { show-pointer :: bool }`
- `λ screenshot-window :: { write-to-disk :: bool }`
- `toggle-keyboard-shortcuts-inhibit`
- `close-window`
- `fullscreen-window`
- `toggle-windowed-fullscreen` (only on niri-unstable)
- `λ focus-window-in-column :: u8`
- `focus-window-previous`
- `focus-column-left`
- `focus-column-right`
- `focus-column-first`
- `focus-column-last`
- `focus-column-right-or-first`
- `focus-column-left-or-last`
- `λ focus-column :: usize` (only on niri-unstable)
- `focus-window-or-monitor-up`
- `focus-window-or-monitor-down`
- `focus-column-or-monitor-left`
- `focus-column-or-monitor-right`
- `focus-window-down`
- `focus-window-up`
- `focus-window-down-or-column-left`
- `focus-window-down-or-column-right`
- `focus-window-up-or-column-left`
- `focus-window-up-or-column-right`
- `focus-window-or-workspace-down`
- `focus-window-or-workspace-up`
- `focus-window-top`
- `focus-window-bottom`
- `focus-window-down-or-top`
- `focus-window-up-or-bottom`
- `move-column-left`
- `move-column-right`
- `move-column-to-first`
- `move-column-to-last`
- `move-column-left-or-to-monitor-left`
- `move-column-right-or-to-monitor-right`
- `λ move-column-to-index :: usize` (only on niri-unstable)
- `move-window-down`
- `move-window-up`
- `move-window-down-or-to-workspace-down`
- `move-window-up-or-to-workspace-up`
- `consume-or-expel-window-left`
- `consume-or-expel-window-right`
- `consume-window-into-column`
- `expel-window-from-column`
- `swap-window-left`
- `swap-window-right`
- `toggle-column-tabbed-display`
- `λ set-column-display :: string`
- `center-column`
- `center-window`
- `center-visible-columns` (only on niri-unstable)
- `focus-workspace-down`
- `focus-workspace-up`
- `λ focus-workspace :: u8 | string`
- `focus-workspace-previous`
- `move-window-to-workspace-down`
- `move-window-to-workspace-up`
- `λ move-column-to-workspace-down :: { focus :: bool }`
- `λ move-column-to-workspace-up :: { focus :: bool }`
- `move-workspace-down`
- `move-workspace-up`
- `λ move-workspace-to-index :: usize`
- `λ move-workspace-to-monitor :: string`
- `λ set-workspace-name :: string`
- `unset-workspace-name`
- `focus-monitor-left`
- `focus-monitor-right`
- `focus-monitor-down`
- `focus-monitor-up`
- `focus-monitor-previous`
- `focus-monitor-next`
- `λ focus-monitor :: string` (only on niri-unstable)
- `move-window-to-monitor-left`
- `move-window-to-monitor-right`
- `move-window-to-monitor-down`
- `move-window-to-monitor-up`
- `move-window-to-monitor-previous`
- `move-window-to-monitor-next`
- `λ move-window-to-monitor :: string` (only on niri-unstable)
- `move-column-to-monitor-left`
- `move-column-to-monitor-right`
- `move-column-to-monitor-down`
- `move-column-to-monitor-up`
- `move-column-to-monitor-previous`
- `move-column-to-monitor-next`
- `λ move-column-to-monitor :: string` (only on niri-unstable)
- `λ set-window-width :: size-change`
- `λ set-window-height :: size-change`
- `reset-window-height`
- `switch-preset-column-width`
- `switch-preset-window-width`
- `switch-preset-window-height`
- `maximize-column`
- `λ set-column-width :: size-change`
- `expand-column-to-available-width`
- `λ switch-layout :: "next" | "prev"`
- `show-hotkey-overlay`
- `move-workspace-to-monitor-left`
- `move-workspace-to-monitor-right`
- `move-workspace-to-monitor-down`
- `move-workspace-to-monitor-up`
- `move-workspace-to-monitor-previous`
- `move-workspace-to-monitor-next`
- `toggle-window-floating`
- `move-window-to-floating`
- `move-window-to-tiling`
- `focus-floating`
- `focus-tiling`
- `switch-focus-between-floating-and-tiling`
- `toggle-window-rule-opacity`
- `set-dynamic-cast-window` (only on niri-unstable)
- `λ set-dynamic-cast-monitor :: unknown` (only on niri-unstable)

  The code that generates this documentation does not know how to parse the definition:
  ```rs
  SetDynamicCastMonitor(#[knuffel(argument)] Option<String>)
  ```

- `clear-dynamic-cast-target` (only on niri-unstable)
- `toggle-overview` (only on niri-unstable)
- `open-overview` (only on niri-unstable)
- `close-overview` (only on niri-unstable)


<!-- sorting key: programs.niri.settings.a.binds.allow-inhibiting -->
## `programs.niri.settings.binds.<name>.allow-inhibiting`
- type: `boolean`
- default: `true`

When a surface is inhibiting keyboard shortcuts, this option dictates wether *this* keybind will be inhibited as well.

By default it is true for all keybinds, meaning an application can block this keybind from being triggered, and the application will receive the key event instead.

When false, this keybind will always be triggered, even if an application is inhibiting keybinds. There is no way for a client to observe this keypress.

Has no effect when `action` is `toggle-keyboard-shortcuts-inhibit`. In that case, this value is implicitly false, no matter what you set it to. (note that the value reported in the nix config may be inaccurate in that case; although hopefully you're not relying on the values of specific keybinds for the rest of your config?)


<!-- sorting key: programs.niri.settings.a.binds.allow-when-locked -->
## `programs.niri.settings.binds.<name>.allow-when-locked`
- type: `boolean`
- default: `false`

Whether this keybind should be allowed when the screen is locked.

This is only applicable for `spawn` keybinds.


<!-- sorting key: programs.niri.settings.a.binds.cooldown-ms -->
## `programs.niri.settings.binds.<name>.cooldown-ms`
- type: `null or signed integer`
- default: `null`

The minimum cooldown before a keybind can be triggered again, in milliseconds.

This is mostly useful for binds on the mouse wheel, where you might not want to activate an action several times in quick succession. You can use it for any bind, though.


<!-- sorting key: programs.niri.settings.a.binds.hotkey-overlay -->
## `programs.niri.settings.binds.<name>.hotkey-overlay`
- type: `variant of: hidden | title`
- default:
  ```nix
  {
    hidden = false;
  }
  ```


How this keybind should be displayed in the hotkey overlay.

- By default, `{hidden = false;}` maps to omitting this from the KDL config; the default title of the action will be used.
- `{hidden = true;}` will emit `hotkey-overlay-title=null` in the KDL config, and the hotkey overlay will not contain this keybind at all.
- `{title = "foo";}` will emit `hotkey-overlay-title="foo"` in the KDL config, and the hotkey overlay will show "foo" as the title of this keybind.


<!-- sorting key: programs.niri.settings.a.binds.hotkey-overlay.hidden -->
## `programs.niri.settings.binds.<name>.hotkey-overlay.hidden`
- type: `boolean`

When `true`, the hotkey overlay will not contain this keybind at all. When `false`, it will show the default title of the action.


<!-- sorting key: programs.niri.settings.a.binds.hotkey-overlay.title -->
## `programs.niri.settings.binds.<name>.hotkey-overlay.title`
- type: `string`

The title of this keybind in the hotkey overlay. [Pango markup](https://docs.gtk.org/Pango/pango_markup.html) is supported.


<!-- sorting key: programs.niri.settings.a.binds.repeat -->
## `programs.niri.settings.binds.<name>.repeat`
- type: `boolean`
- default: `true`

Whether this keybind should trigger repeatedly when held down.


<!-- sorting key: programs.niri.settings.a.switch-events -->
<!-- programs.niri.settings.switch-events -->

<!-- sorting key: programs.niri.settings.a.switch-events.a.lid-close -->
## `programs.niri.settings.switch-events.lid-close`
- type: `null or `[`<switch-bind>`](#switch-bind)
- default: `null`


<!-- sorting key: programs.niri.settings.a.switch-events.a.lid-open -->
## `programs.niri.settings.switch-events.lid-open`
- type: `null or `[`<switch-bind>`](#switch-bind)
- default: `null`


<!-- sorting key: programs.niri.settings.a.switch-events.a.tablet-mode-off -->
## `programs.niri.settings.switch-events.tablet-mode-off`
- type: `null or `[`<switch-bind>`](#switch-bind)
- default: `null`


<!-- sorting key: programs.niri.settings.a.switch-events.a.tablet-mode-on -->
## `programs.niri.settings.switch-events.tablet-mode-on`
- type: `null or `[`<switch-bind>`](#switch-bind)
- default: `null`


<!-- sorting key: programs.niri.settings.a.switch-events.b.<switch-bind> -->
## `<switch-bind>`
- type: `niri switch bind`

<!--
This description doesn't matter to the docs, but is necessary to make this header actually render so the above types can link to it.
-->


<!-- sorting key: programs.niri.settings.a.switch-events.b.<switch-bind>.action -->
## `<switch-bind>.action`
- type: `niri switch action`, which is a `kdl leaf`

A switch action is represented as an attrset with a single key, being the name, and a value that is a list of its arguments.

See also [`binds.<name>.action`](#programsnirisettingsbindsnameaction) for more information on how this works, it has the exact same option type. Beware that switch binds are not the same as regular binds, and the actions they take are different. Currently, they can only accept spawn binds. Correct usage is like so:

```nix
{
  programs.niri.settings.switch-events = {
    tablet-mode-on.action.spawn = ["gsettings" "set" "org.gnome.desktop.a11y.applications" "screen-keyboard-enabled" "true"];
    tablet-mode-off.action.spawn = ["gsettings" "set" "org.gnome.desktop.a11y.applications" "screen-keyboard-enabled" "false"];
  };
}
```


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


<!-- sorting key: programs.niri.settings.d.clipboard.disable-primary -->
## `programs.niri.settings.clipboard.disable-primary`
- type: `boolean`
- default: `false`

The "primary selection" is a special clipboard that contains the text that was last selected with the mouse, and can usually be pasted with the middle mouse button.

This is a feature that is not inherently part of the core Wayland protocol, but [a widely supported protocol extension](https://wayland.app/protocols/primary-selection-unstable-v1#compositor-support) enables support for it anyway.

This functionality was inherited from X11, is not necessarily intuitive to many users; especially those coming from other operating systems that do not have this feature (such as Windows, where the middle mouse button is used for scrolling).

If you don't want to have a primary selection, you can disable it with this option. Doing so will prevent niri from adveritising support for the primary selection protocol.

Note that this option has nothing to do with the "clipboard" that is commonly invoked with `Ctrl+C` and `Ctrl+V`.


<!-- sorting key: programs.niri.settings.e.prefer-no-csd -->
## `programs.niri.settings.prefer-no-csd`
- type: `boolean`
- default: `false`

Whether to prefer server-side decorations (SSD) over client-side decorations (CSD).


<!-- sorting key: programs.niri.settings.f.spawn-at-startup -->
## `programs.niri.settings.spawn-at-startup`
- type: `list of (submodule)`


<!-- sorting key: programs.niri.settings.f.spawn-at-startup.command -->
## `programs.niri.settings.spawn-at-startup.*.command`
- type: `list of string`


<!-- sorting key: programs.niri.settings.g.workspaces -->
## `programs.niri.settings.workspaces`
- type: `attribute set of (submodule)`

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


<!-- sorting key: programs.niri.settings.g.workspaces.name -->
## `programs.niri.settings.workspaces.<name>.name`
- type: `string`
- default: `the key of the workspace`

The name of the workspace. You set this manually if you want the keys to be ordered in a specific way.


<!-- sorting key: programs.niri.settings.g.workspaces.open-on-output -->
## `programs.niri.settings.workspaces.<name>.open-on-output`
- type: `null or string`
- default: `null`

The name of the output the workspace should be assigned to.


<!-- sorting key: programs.niri.settings.h.overview.backdrop-color -->
## `programs.niri.settings.overview.backdrop-color`
- type: `null or string`
- default: `null`

Set the backdrop color behind workspaces in the overview. The backdrop is also visible between workspaces when switching.

The alpha channel for this color will be ignored.


<!-- sorting key: programs.niri.settings.h.overview.zoom -->
## `programs.niri.settings.overview.zoom`
- type: `null or floating point number or signed integer`
- default: `null`

Control how much the workspaces zoom out in the overview. zoom ranges from 0 to 0.75 where lower values make everything smaller.


<!-- sorting key: programs.niri.settings.i.input.focus-follows-mouse.enable -->
## `programs.niri.settings.input.focus-follows-mouse.enable`
- type: `boolean`
- default: `false`

Whether to focus the window under the mouse when the mouse moves.


<!-- sorting key: programs.niri.settings.i.input.focus-follows-mouse.max-scroll-amount -->
## `programs.niri.settings.input.focus-follows-mouse.max-scroll-amount`
- type: `null or string`
- default: `null`

The maximum proportion of the screen to scroll at a time


<!-- sorting key: programs.niri.settings.i.input.keyboard.numlock -->
## `programs.niri.settings.input.keyboard.numlock`
- type: `boolean`
- default: `false`

Enable numlock by default


<!-- sorting key: programs.niri.settings.i.input.keyboard.repeat-delay -->
## `programs.niri.settings.input.keyboard.repeat-delay`
- type: `signed integer`
- default: `600`

The delay in milliseconds before a key starts repeating.


<!-- sorting key: programs.niri.settings.i.input.keyboard.repeat-rate -->
## `programs.niri.settings.input.keyboard.repeat-rate`
- type: `signed integer`
- default: `25`

The rate in characters per second at which a key repeats.


<!-- sorting key: programs.niri.settings.i.input.keyboard.track-layout -->
## `programs.niri.settings.input.keyboard.track-layout`
- type: `one of "global", "window"`
- default: `"global"`

The keyboard layout can be remembered per `"window"`, such that when you switch to a window, the keyboard layout is set to the one that was last used in that window.

By default, there is only one `"global"` keyboard layout and changing it in any window will affect the keyboard layout used in all other windows too.


<!-- sorting key: programs.niri.settings.i.input.keyboard.xkb -->
## `programs.niri.settings.input.keyboard.xkb`


Parameters passed to libxkbcommon, which handles the keyboard in niri.

Further reading:
- [`smithay::wayland::seat::XkbConfig`](https://docs.rs/smithay/latest/smithay/wayland/seat/struct.XkbConfig.html)


<!-- sorting key: programs.niri.settings.i.input.keyboard.xkb.a.file -->
## `programs.niri.settings.input.keyboard.xkb.file`
- type: `null or string`
- default: `null`

Path to a `.xkb` keymap file. If set, this file will be used to configure libxkbcommon, and all other options will be ignored.


<!-- sorting key: programs.niri.settings.i.input.keyboard.xkb.b.layout -->
## `programs.niri.settings.input.keyboard.xkb.layout`
- type: `string`
- default: `""`

A comma-separated list of layouts (languages) to include in the keymap.

See [`xkeyboard-config(7)`](https://man.archlinux.org/man/xkeyboard-config.7#LAYOUTS) for a list of available layouts and their variants.

If this is set to an empty string, the layout will be read from the `XKB_DEFAULT_LAYOUT` environment variable.



<!-- sorting key: programs.niri.settings.i.input.keyboard.xkb.b.model -->
## `programs.niri.settings.input.keyboard.xkb.model`
- type: `string`
- default: `""`

The keyboard model by which to interpret keycodes and LEDs

See [`xkeyboard-config(7)`](https://man.archlinux.org/man/xkeyboard-config.7#MODELS) for a list of available models.

If this is set to an empty string, the model will be read from the `XKB_DEFAULT_MODEL` environment variable.



<!-- sorting key: programs.niri.settings.i.input.keyboard.xkb.b.options -->
## `programs.niri.settings.input.keyboard.xkb.options`
- type: `null or string`
- default: `null`

A comma separated list of options, through which the user specifies non-layout related preferences, like which key combinations are used for switching layouts, or which key is the Compose key.

See [`xkeyboard-config(7)`](https://man.archlinux.org/man/xkeyboard-config.7#OPTIONS) for a list of available options.

If this is set to an empty string, no options will be used.

If this is set to null, the options will be read from the `XKB_DEFAULT_OPTIONS` environment variable.



<!-- sorting key: programs.niri.settings.i.input.keyboard.xkb.b.rules -->
## `programs.niri.settings.input.keyboard.xkb.rules`
- type: `string`
- default: `""`

The rules file to use.

The rules file describes how to interpret the values of the model, layout, variant and options fields.

If this is set to an empty string, the rules will be read from the `XKB_DEFAULT_RULES` environment variable.



<!-- sorting key: programs.niri.settings.i.input.keyboard.xkb.b.variant -->
## `programs.niri.settings.input.keyboard.xkb.variant`
- type: `string`
- default: `""`

A comma separated list of variants, one per layout, which may modify or augment the respective layout in various ways.

See [`xkeyboard-config(7)`](https://man.archlinux.org/man/xkeyboard-config.7#LAYOUTS) for a list of available variants for each layout.

If this is set to an empty string, the variant will be read from the `XKB_DEFAULT_VARIANT` environment variable.



<!-- sorting key: programs.niri.settings.i.input.mod-key -->
## `programs.niri.settings.input.mod-key`
- type: `null or string`
- default: `null`


<!-- sorting key: programs.niri.settings.i.input.mod-key-nested -->
## `programs.niri.settings.input.mod-key-nested`
- type: `null or string`
- default: `null`


<!-- sorting key: programs.niri.settings.i.input.mouse.accel-profile -->
## `programs.niri.settings.input.mouse.accel-profile`
- type: `null or one of "adaptive", "flat"`
- default: `null`

Further reading:
- https://wayland.freedesktop.org/libinput/doc/latest/pointer-acceleration.html#pointer-acceleration-profiles


<!-- sorting key: programs.niri.settings.i.input.mouse.accel-speed -->
## `programs.niri.settings.input.mouse.accel-speed`
- type: `floating point number`
- default: `0.000000`

Further reading:
- https://wayland.freedesktop.org/libinput/doc/latest/configuration.html#pointer-acceleration


<!-- sorting key: programs.niri.settings.i.input.mouse.enable -->
## `programs.niri.settings.input.mouse.enable`
- type: `boolean`
- default: `true`


<!-- sorting key: programs.niri.settings.i.input.mouse.left-handed -->
## `programs.niri.settings.input.mouse.left-handed`
- type: `boolean`
- default: `false`

Whether to accomodate left-handed usage for this device.
This varies based on the exact device, but will for example swap left/right mouse buttons.

Further reading:
- https://wayland.freedesktop.org/libinput/doc/latest/configuration.html#left-handed-mode


<!-- sorting key: programs.niri.settings.i.input.mouse.middle-emulation -->
## `programs.niri.settings.input.mouse.middle-emulation`
- type: `boolean`
- default: `false`

Whether a middle mouse button press should be sent when you press the left and right mouse buttons

Further reading:
- https://wayland.freedesktop.org/libinput/doc/latest/configuration.html#middle-button-emulation
- https://wayland.freedesktop.org/libinput/doc/latest/middle-button-emulation.html#middle-button-emulation


<!-- sorting key: programs.niri.settings.i.input.mouse.natural-scroll -->
## `programs.niri.settings.input.mouse.natural-scroll`
- type: `boolean`
- default: `false`

Whether scrolling should move the content in the scrolled direction (as opposed to moving the viewport)

Further reading:
- https://wayland.freedesktop.org/libinput/doc/latest/configuration.html#scrolling
- https://wayland.freedesktop.org/libinput/doc/latest/scrolling.html#natural-scrolling-vs-traditional-scrolling


<!-- sorting key: programs.niri.settings.i.input.mouse.scroll-button -->
## `programs.niri.settings.input.mouse.scroll-button`
- type: `null or signed integer`
- default: `null`

When `scroll-method = "on-button-down"`, this is the button that will be used to enable scrolling. This button must be on the same physical device as the pointer, according to libinput docs. The type is a button code, as defined in [`input-event-codes.h`](https://github.com/torvalds/linux/blob/e42b1a9a2557aa94fee47f078633677198386a52/include/uapi/linux/input-event-codes.h#L355-L363). Most commonly, this will be set to `BTN_LEFT`, `BTN_MIDDLE`, or `BTN_RIGHT`, or at least some mouse button, but any button from that file is a valid value for this option (though, libinput may not necessarily do anything useful with most of them)

Further reading:
- https://wayland.freedesktop.org/libinput/doc/latest/scrolling.html#on-button-scrolling


<!-- sorting key: programs.niri.settings.i.input.mouse.scroll-factor -->
## `programs.niri.settings.input.mouse.scroll-factor`
- type: `null or floating point number`
- default: `null`

For all scroll events triggered by a wheel source, the scroll distance is multiplied by this factor.

This is not a libinput property, but rather a niri-specific one.


<!-- sorting key: programs.niri.settings.i.input.mouse.scroll-method -->
## `programs.niri.settings.input.mouse.scroll-method`
- type: `null or one of "no-scroll", "two-finger", "edge", "on-button-down"`
- default: `null`

When to convert motion events to scrolling events.
The default and supported values vary based on the device type.

Further reading:
- https://wayland.freedesktop.org/libinput/doc/latest/scrolling.html#scrolling


<!-- sorting key: programs.niri.settings.i.input.power-key-handling.enable -->
## `programs.niri.settings.input.power-key-handling.enable`
- type: `boolean`
- default: `true`

By default, niri will take over the power button to make it sleep instead of power off.

You can disable this behaviour if you prefer to configure the power button elsewhere.


<!-- sorting key: programs.niri.settings.i.input.tablet.calibration-matrix -->
## `programs.niri.settings.input.tablet.calibration-matrix`
- type: `null or (2x3 matrix)`
- default: `null`

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


<!-- sorting key: programs.niri.settings.i.input.tablet.enable -->
## `programs.niri.settings.input.tablet.enable`
- type: `boolean`
- default: `true`


<!-- sorting key: programs.niri.settings.i.input.tablet.left-handed -->
## `programs.niri.settings.input.tablet.left-handed`
- type: `boolean`
- default: `false`

Whether to accomodate left-handed usage for this device.
This varies based on the exact device, but will for example swap left/right mouse buttons.

Further reading:
- https://wayland.freedesktop.org/libinput/doc/latest/configuration.html#left-handed-mode


<!-- sorting key: programs.niri.settings.i.input.tablet.map-to-output -->
## `programs.niri.settings.input.tablet.map-to-output`
- type: `null or string`
- default: `null`


<!-- sorting key: programs.niri.settings.i.input.touch.enable -->
## `programs.niri.settings.input.touch.enable`
- type: `boolean`
- default: `true`


<!-- sorting key: programs.niri.settings.i.input.touch.map-to-output -->
## `programs.niri.settings.input.touch.map-to-output`
- type: `null or string`
- default: `null`


<!-- sorting key: programs.niri.settings.i.input.touchpad.accel-profile -->
## `programs.niri.settings.input.touchpad.accel-profile`
- type: `null or one of "adaptive", "flat"`
- default: `null`

Further reading:
- https://wayland.freedesktop.org/libinput/doc/latest/pointer-acceleration.html#pointer-acceleration-profiles


<!-- sorting key: programs.niri.settings.i.input.touchpad.accel-speed -->
## `programs.niri.settings.input.touchpad.accel-speed`
- type: `floating point number`
- default: `0.000000`

Further reading:
- https://wayland.freedesktop.org/libinput/doc/latest/configuration.html#pointer-acceleration


<!-- sorting key: programs.niri.settings.i.input.touchpad.click-method -->
## `programs.niri.settings.input.touchpad.click-method`
- type: `null or one of "button-areas", "clickfinger"`
- default: `null`

Method to determine which mouse button is pressed when you click the touchpad.

- `"button-areas"`: [Software button areas](https://wayland.freedesktop.org/libinput/doc/latest/clickpad-softbuttons.html#software-button-areas) \
  The button is determined by which part of the touchpad was clicked.

- `"clickfinger"`: [Clickfinger behavior](https://wayland.freedesktop.org/libinput/doc/latest/clickpad-softbuttons.html#clickfinger-behavior) \
  The button is determined by how many fingers clicked.

Further reading:
- https://wayland.freedesktop.org/libinput/doc/latest/configuration.html#click-method
- https://wayland.freedesktop.org/libinput/doc/latest/clickpad-softbuttons.html#clickpad-software-button-behavior


<!-- sorting key: programs.niri.settings.i.input.touchpad.disabled-on-external-mouse -->
## `programs.niri.settings.input.touchpad.disabled-on-external-mouse`
- type: `boolean`
- default: `false`

Whether to disable the touchpad when an external mouse is plugged in.

Further reading:
- https://wayland.freedesktop.org/libinput/doc/latest/configuration.html#send-events-mode


<!-- sorting key: programs.niri.settings.i.input.touchpad.drag -->
## `programs.niri.settings.input.touchpad.drag`
- type: `null or boolean`
- default: `null`

On most touchpads, "tap and drag" is enabled by default. This option allows you to explicitly enable or disable it.

Tap and drag means that to drag an item, you tap the touchpad with some amount of fingers to decide what kind of button press is emulated, but don't hold those fingers, and then you immediately start dragging with one finger.

Further reading:
- https://wayland.freedesktop.org/libinput/doc/latest/tapping.html#tap-and-drag


<!-- sorting key: programs.niri.settings.i.input.touchpad.drag-lock -->
## `programs.niri.settings.input.touchpad.drag-lock`
- type: `boolean`
- default: `false`

By default, a "tap and drag" gesture is terminated by releasing the finger that is dragging.

Drag lock means that the drag gesture is not terminated when the finger is released, but only when the finger is tapped again, or after a timeout (unless sticky mode is enabled). This allows you to reset your finger position without losing the drag gesture.

Drag lock is only applicable when tap and drag is enabled.

Further reading:
- https://wayland.freedesktop.org/libinput/doc/latest/tapping.html#tap-and-drag


<!-- sorting key: programs.niri.settings.i.input.touchpad.dwt -->
## `programs.niri.settings.input.touchpad.dwt`
- type: `boolean`
- default: `false`

Whether to disable the touchpad while typing.

Further reading:
- https://wayland.freedesktop.org/libinput/doc/latest/configuration.html#disable-while-typing
- https://wayland.freedesktop.org/libinput/doc/latest/palm-detection.html#disable-while-typing


<!-- sorting key: programs.niri.settings.i.input.touchpad.dwtp -->
## `programs.niri.settings.input.touchpad.dwtp`
- type: `boolean`
- default: `false`

Whether to disable the touchpad while the trackpoint is in use.

Further reading:
- https://wayland.freedesktop.org/libinput/doc/latest/configuration.html#disable-while-trackpointing
- https://wayland.freedesktop.org/libinput/doc/latest/palm-detection.html#disable-while-trackpointing


<!-- sorting key: programs.niri.settings.i.input.touchpad.enable -->
## `programs.niri.settings.input.touchpad.enable`
- type: `boolean`
- default: `true`


<!-- sorting key: programs.niri.settings.i.input.touchpad.left-handed -->
## `programs.niri.settings.input.touchpad.left-handed`
- type: `boolean`
- default: `false`

Whether to accomodate left-handed usage for this device.
This varies based on the exact device, but will for example swap left/right mouse buttons.

Further reading:
- https://wayland.freedesktop.org/libinput/doc/latest/configuration.html#left-handed-mode


<!-- sorting key: programs.niri.settings.i.input.touchpad.middle-emulation -->
## `programs.niri.settings.input.touchpad.middle-emulation`
- type: `boolean`
- default: `false`

Whether a middle mouse button press should be sent when you press the left and right mouse buttons

Further reading:
- https://wayland.freedesktop.org/libinput/doc/latest/configuration.html#middle-button-emulation
- https://wayland.freedesktop.org/libinput/doc/latest/middle-button-emulation.html#middle-button-emulation


<!-- sorting key: programs.niri.settings.i.input.touchpad.natural-scroll -->
## `programs.niri.settings.input.touchpad.natural-scroll`
- type: `boolean`
- default: `true`

Whether scrolling should move the content in the scrolled direction (as opposed to moving the viewport)

Further reading:
- https://wayland.freedesktop.org/libinput/doc/latest/configuration.html#scrolling
- https://wayland.freedesktop.org/libinput/doc/latest/scrolling.html#natural-scrolling-vs-traditional-scrolling


<!-- sorting key: programs.niri.settings.i.input.touchpad.scroll-button -->
## `programs.niri.settings.input.touchpad.scroll-button`
- type: `null or signed integer`
- default: `null`

When `scroll-method = "on-button-down"`, this is the button that will be used to enable scrolling. This button must be on the same physical device as the pointer, according to libinput docs. The type is a button code, as defined in [`input-event-codes.h`](https://github.com/torvalds/linux/blob/e42b1a9a2557aa94fee47f078633677198386a52/include/uapi/linux/input-event-codes.h#L355-L363). Most commonly, this will be set to `BTN_LEFT`, `BTN_MIDDLE`, or `BTN_RIGHT`, or at least some mouse button, but any button from that file is a valid value for this option (though, libinput may not necessarily do anything useful with most of them)

Further reading:
- https://wayland.freedesktop.org/libinput/doc/latest/scrolling.html#on-button-scrolling


<!-- sorting key: programs.niri.settings.i.input.touchpad.scroll-factor -->
## `programs.niri.settings.input.touchpad.scroll-factor`
- type: `null or floating point number`
- default: `null`

For all scroll events triggered by a finger source, the scroll distance is multiplied by this factor.

This is not a libinput property, but rather a niri-specific one.


<!-- sorting key: programs.niri.settings.i.input.touchpad.scroll-method -->
## `programs.niri.settings.input.touchpad.scroll-method`
- type: `null or one of "no-scroll", "two-finger", "edge", "on-button-down"`
- default: `null`

When to convert motion events to scrolling events.
The default and supported values vary based on the device type.

Further reading:
- https://wayland.freedesktop.org/libinput/doc/latest/scrolling.html#scrolling


<!-- sorting key: programs.niri.settings.i.input.touchpad.tap -->
## `programs.niri.settings.input.touchpad.tap`
- type: `boolean`
- default: `true`

Whether to enable tap-to-click.

Further reading:
- https://wayland.freedesktop.org/libinput/doc/latest/configuration.html#tap-to-click
- https://wayland.freedesktop.org/libinput/doc/latest/tapping.html#tap-to-click-behaviour


<!-- sorting key: programs.niri.settings.i.input.touchpad.tap-button-map -->
## `programs.niri.settings.input.touchpad.tap-button-map`
- type: `null or one of "left-middle-right", "left-right-middle"`
- default: `null`

The mouse button to register when tapping with 1, 2, or 3 fingers, when [`input.touchpad.tap`](#programsnirisettingsinputtouchpadtap) is enabled.

Further reading:
- https://wayland.freedesktop.org/libinput/doc/latest/configuration.html#tap-to-click


<!-- sorting key: programs.niri.settings.i.input.trackball.accel-profile -->
## `programs.niri.settings.input.trackball.accel-profile`
- type: `null or one of "adaptive", "flat"`
- default: `null`

Further reading:
- https://wayland.freedesktop.org/libinput/doc/latest/pointer-acceleration.html#pointer-acceleration-profiles


<!-- sorting key: programs.niri.settings.i.input.trackball.accel-speed -->
## `programs.niri.settings.input.trackball.accel-speed`
- type: `floating point number`
- default: `0.000000`

Further reading:
- https://wayland.freedesktop.org/libinput/doc/latest/configuration.html#pointer-acceleration


<!-- sorting key: programs.niri.settings.i.input.trackball.enable -->
## `programs.niri.settings.input.trackball.enable`
- type: `boolean`
- default: `true`


<!-- sorting key: programs.niri.settings.i.input.trackball.left-handed -->
## `programs.niri.settings.input.trackball.left-handed`
- type: `boolean`
- default: `false`

Whether to accomodate left-handed usage for this device.
This varies based on the exact device, but will for example swap left/right mouse buttons.

Further reading:
- https://wayland.freedesktop.org/libinput/doc/latest/configuration.html#left-handed-mode


<!-- sorting key: programs.niri.settings.i.input.trackball.middle-emulation -->
## `programs.niri.settings.input.trackball.middle-emulation`
- type: `boolean`
- default: `false`

Whether a middle mouse button press should be sent when you press the left and right mouse buttons

Further reading:
- https://wayland.freedesktop.org/libinput/doc/latest/configuration.html#middle-button-emulation
- https://wayland.freedesktop.org/libinput/doc/latest/middle-button-emulation.html#middle-button-emulation


<!-- sorting key: programs.niri.settings.i.input.trackball.natural-scroll -->
## `programs.niri.settings.input.trackball.natural-scroll`
- type: `boolean`
- default: `false`

Whether scrolling should move the content in the scrolled direction (as opposed to moving the viewport)

Further reading:
- https://wayland.freedesktop.org/libinput/doc/latest/configuration.html#scrolling
- https://wayland.freedesktop.org/libinput/doc/latest/scrolling.html#natural-scrolling-vs-traditional-scrolling


<!-- sorting key: programs.niri.settings.i.input.trackball.scroll-button -->
## `programs.niri.settings.input.trackball.scroll-button`
- type: `null or signed integer`
- default: `null`

When `scroll-method = "on-button-down"`, this is the button that will be used to enable scrolling. This button must be on the same physical device as the pointer, according to libinput docs. The type is a button code, as defined in [`input-event-codes.h`](https://github.com/torvalds/linux/blob/e42b1a9a2557aa94fee47f078633677198386a52/include/uapi/linux/input-event-codes.h#L355-L363). Most commonly, this will be set to `BTN_LEFT`, `BTN_MIDDLE`, or `BTN_RIGHT`, or at least some mouse button, but any button from that file is a valid value for this option (though, libinput may not necessarily do anything useful with most of them)

Further reading:
- https://wayland.freedesktop.org/libinput/doc/latest/scrolling.html#on-button-scrolling


<!-- sorting key: programs.niri.settings.i.input.trackball.scroll-method -->
## `programs.niri.settings.input.trackball.scroll-method`
- type: `null or one of "no-scroll", "two-finger", "edge", "on-button-down"`
- default: `null`

When to convert motion events to scrolling events.
The default and supported values vary based on the device type.

Further reading:
- https://wayland.freedesktop.org/libinput/doc/latest/scrolling.html#scrolling


<!-- sorting key: programs.niri.settings.i.input.trackpoint.accel-profile -->
## `programs.niri.settings.input.trackpoint.accel-profile`
- type: `null or one of "adaptive", "flat"`
- default: `null`

Further reading:
- https://wayland.freedesktop.org/libinput/doc/latest/pointer-acceleration.html#pointer-acceleration-profiles


<!-- sorting key: programs.niri.settings.i.input.trackpoint.accel-speed -->
## `programs.niri.settings.input.trackpoint.accel-speed`
- type: `floating point number`
- default: `0.000000`

Further reading:
- https://wayland.freedesktop.org/libinput/doc/latest/configuration.html#pointer-acceleration


<!-- sorting key: programs.niri.settings.i.input.trackpoint.enable -->
## `programs.niri.settings.input.trackpoint.enable`
- type: `boolean`
- default: `true`


<!-- sorting key: programs.niri.settings.i.input.trackpoint.left-handed -->
## `programs.niri.settings.input.trackpoint.left-handed`
- type: `boolean`
- default: `false`

Whether to accomodate left-handed usage for this device.
This varies based on the exact device, but will for example swap left/right mouse buttons.

Further reading:
- https://wayland.freedesktop.org/libinput/doc/latest/configuration.html#left-handed-mode


<!-- sorting key: programs.niri.settings.i.input.trackpoint.middle-emulation -->
## `programs.niri.settings.input.trackpoint.middle-emulation`
- type: `boolean`
- default: `false`

Whether a middle mouse button press should be sent when you press the left and right mouse buttons

Further reading:
- https://wayland.freedesktop.org/libinput/doc/latest/configuration.html#middle-button-emulation
- https://wayland.freedesktop.org/libinput/doc/latest/middle-button-emulation.html#middle-button-emulation


<!-- sorting key: programs.niri.settings.i.input.trackpoint.natural-scroll -->
## `programs.niri.settings.input.trackpoint.natural-scroll`
- type: `boolean`
- default: `false`

Whether scrolling should move the content in the scrolled direction (as opposed to moving the viewport)

Further reading:
- https://wayland.freedesktop.org/libinput/doc/latest/configuration.html#scrolling
- https://wayland.freedesktop.org/libinput/doc/latest/scrolling.html#natural-scrolling-vs-traditional-scrolling


<!-- sorting key: programs.niri.settings.i.input.trackpoint.scroll-button -->
## `programs.niri.settings.input.trackpoint.scroll-button`
- type: `null or signed integer`
- default: `null`

When `scroll-method = "on-button-down"`, this is the button that will be used to enable scrolling. This button must be on the same physical device as the pointer, according to libinput docs. The type is a button code, as defined in [`input-event-codes.h`](https://github.com/torvalds/linux/blob/e42b1a9a2557aa94fee47f078633677198386a52/include/uapi/linux/input-event-codes.h#L355-L363). Most commonly, this will be set to `BTN_LEFT`, `BTN_MIDDLE`, or `BTN_RIGHT`, or at least some mouse button, but any button from that file is a valid value for this option (though, libinput may not necessarily do anything useful with most of them)

Further reading:
- https://wayland.freedesktop.org/libinput/doc/latest/scrolling.html#on-button-scrolling


<!-- sorting key: programs.niri.settings.i.input.trackpoint.scroll-method -->
## `programs.niri.settings.input.trackpoint.scroll-method`
- type: `null or one of "no-scroll", "two-finger", "edge", "on-button-down"`
- default: `null`

When to convert motion events to scrolling events.
The default and supported values vary based on the device type.

Further reading:
- https://wayland.freedesktop.org/libinput/doc/latest/scrolling.html#scrolling


<!-- sorting key: programs.niri.settings.i.input.warp-mouse-to-focus -->
## `programs.niri.settings.input.warp-mouse-to-focus`


Whether to warp the mouse to the focused window when switching focus.


<!-- sorting key: programs.niri.settings.i.input.warp-mouse-to-focus.enable -->
## `programs.niri.settings.input.warp-mouse-to-focus.enable`
- type: `boolean`
- default: `false`


<!-- sorting key: programs.niri.settings.i.input.warp-mouse-to-focus.mode -->
## `programs.niri.settings.input.warp-mouse-to-focus.mode`
- type: `null or string`
- default: `null`


<!-- sorting key: programs.niri.settings.i.input.workspace-auto-back-and-forth -->
## `programs.niri.settings.input.workspace-auto-back-and-forth`
- type: `boolean`
- default: `false`

When invoking `focus-workspace` to switch to a workspace by index, if the workspace is already focused, usually nothing happens. When this option is enabled, the workspace will cycle back to the previously active workspace.

Of note is that it does not switch to the previous *index*, but the previous *workspace*. That means you can reorder workspaces inbetween these actions, and it will still take you to the actual same workspace you came from.


<!-- sorting key: programs.niri.settings.j.outputs -->
## `programs.niri.settings.outputs`
- type: `attribute set of (submodule)`


<!-- sorting key: programs.niri.settings.j.outputs.backdrop-color -->
## `programs.niri.settings.outputs.<name>.backdrop-color`
- type: `null or string`
- default: `null`

> [!important]
> This option is not yet available in stable niri.
>
> If you wish to modify this option, you should make sure [`programs.niri.package`](#programsniripackage) is set to [`pkgs.niri-unstable`](#packagessystemniri-unstable).
>
> Otherwise, your system might fail to build.


The backdrop color that niri draws for this output. This is visible between workspaces or in the overview.


<!-- sorting key: programs.niri.settings.j.outputs.background-color -->
## `programs.niri.settings.outputs.<name>.background-color`
- type: `null or string`
- default: `null`

The background color of this output. This is equivalent to launching `swaybg -c <color>` on that output, but is handled by the compositor itself for solid colors.


<!-- sorting key: programs.niri.settings.j.outputs.enable -->
## `programs.niri.settings.outputs.<name>.enable`
- type: `boolean`
- default: `true`


<!-- sorting key: programs.niri.settings.j.outputs.focus-at-startup -->
## `programs.niri.settings.outputs.<name>.focus-at-startup`
- type: `boolean`
- default: `false`

Focus this output by default when niri starts.

If multiple outputs with `focus-at-startup` are connected, then the one with the key that sorts first will be focused. You can change the key to affect the sorting order, and set [`outputs.<name>.name`](#programsnirisettingsoutputsnamename) to be the actual name of the output.

When none of the connected outputs are explicitly focus-at-startup, niri will focus the first one sorted by name (same output sorting as used elsewhere in niri).


<!-- sorting key: programs.niri.settings.j.outputs.mode -->
## `programs.niri.settings.outputs.<name>.mode`
- type: `null or (submodule)`
- default: `null`

The resolution and refresh rate of this display.

By default, when this is null, niri will automatically pick a mode for you.

If this is set to an invalid mode (i.e unsupported by this output), niri will act as if it is unset and pick one for you.


<!-- sorting key: programs.niri.settings.j.outputs.mode.height -->
## `programs.niri.settings.outputs.<name>.mode.height`
- type: `signed integer`


<!-- sorting key: programs.niri.settings.j.outputs.mode.refresh -->
## `programs.niri.settings.outputs.<name>.mode.refresh`
- type: `null or floating point number`
- default: `null`

The refresh rate of this output. When this is null, but the resolution is set, niri will automatically pick the highest available refresh rate.


<!-- sorting key: programs.niri.settings.j.outputs.mode.width -->
## `programs.niri.settings.outputs.<name>.mode.width`
- type: `signed integer`


<!-- sorting key: programs.niri.settings.j.outputs.name -->
## `programs.niri.settings.outputs.<name>.name`
- type: `string`
- default: `the key of the output`

The name of the output. You set this manually if you want the outputs to be ordered in a specific way.


<!-- sorting key: programs.niri.settings.j.outputs.position -->
## `programs.niri.settings.outputs.<name>.position`
- type: `null or (submodule)`
- default: `null`

Position of the output in the global coordinate space.

This affects directional monitor actions like "focus-monitor-left", and cursor movement.

The cursor can only move between directly adjacent outputs.

Output scale has to be taken into account for positioning, because outputs are sized in logical pixels.

For example, a 3840x2160 output with scale 2.0 will have a logical size of 1920x1080, so to put another output directly adjacent to it on the right, set its x to 1920.

If the position is unset or multiple outputs overlap, niri will instead place the output automatically.


<!-- sorting key: programs.niri.settings.j.outputs.position.x -->
## `programs.niri.settings.outputs.<name>.position.x`
- type: `signed integer`


<!-- sorting key: programs.niri.settings.j.outputs.position.y -->
## `programs.niri.settings.outputs.<name>.position.y`
- type: `signed integer`


<!-- sorting key: programs.niri.settings.j.outputs.scale -->
## `programs.niri.settings.outputs.<name>.scale`
- type: `null or floating point number or signed integer`
- default: `null`

The scale of this output, which represents how many physical pixels fit in one logical pixel.

If this is null, niri will automatically pick a scale for you.


<!-- sorting key: programs.niri.settings.j.outputs.transform.flipped -->
## `programs.niri.settings.outputs.<name>.transform.flipped`
- type: `boolean`
- default: `false`

Whether to flip this output vertically.


<!-- sorting key: programs.niri.settings.j.outputs.transform.rotation -->
## `programs.niri.settings.outputs.<name>.transform.rotation`
- type: `one of 0, 90, 180, 270`
- default: `0`

Counter-clockwise rotation of this output in degrees.


<!-- sorting key: programs.niri.settings.j.outputs.variable-refresh-rate -->
## `programs.niri.settings.outputs.<name>.variable-refresh-rate`
- type: `one of false, "on-demand", true`
- default: `false`

Whether to enable variable refresh rate (VRR) on this output.

VRR is also known as Adaptive Sync, FreeSync, and G-Sync.

Setting this to `"on-demand"` will enable VRR only when a window with [`window-rules.*.variable-refresh-rate`](#programsnirisettingswindow-rulesvariable-refresh-rate) is present on this output.


<!-- sorting key: programs.niri.settings.k.cursor -->
<!-- programs.niri.settings.cursor -->

<!-- sorting key: programs.niri.settings.k.cursor.hide-after-inactive-ms -->
## `programs.niri.settings.cursor.hide-after-inactive-ms`
- type: `null or signed integer`
- default: `null`

If set, the cursor will automatically hide once this number of milliseconds passes since the last cursor movement.


<!-- sorting key: programs.niri.settings.k.cursor.hide-when-typing -->
## `programs.niri.settings.cursor.hide-when-typing`
- type: `boolean`
- default: `false`

Whether to hide the cursor when typing.


<!-- sorting key: programs.niri.settings.k.cursor.size -->
## `programs.niri.settings.cursor.size`
- type: `signed integer`
- default: `24`

The size of the cursor in logical pixels.

This will also set the XCURSOR_SIZE environment variable for all spawned processes.


<!-- sorting key: programs.niri.settings.k.cursor.theme -->
## `programs.niri.settings.cursor.theme`
- type: `string`
- default: `"default"`

The name of the xcursor theme to use.

This will also set the XCURSOR_THEME environment variable for all spawned processes.


<!-- sorting key: programs.niri.settings.l.layout -->
<!-- programs.niri.settings.layout -->

<!-- sorting key: programs.niri.settings.l.layout.a.border -->
## `programs.niri.settings.layout.border`


The border is a decoration drawn *inside* every window in the layout. It will take space away from windows. That is, if you have a border of 8px, then each window will be 8px smaller on each edge than if you had no border.

The currently focused window, i.e. the window that can receive keyboard input, will be drawn according to [`layout.border.active`](#programsnirisettingslayoutborderactive), and all other windows will be drawn according to [`layout.border.inactive`](#programsnirisettingslayoutborderinactive).

If you have [`layout.focus-ring`](#programsnirisettingslayoutfocus-ring) enabled, the border will be drawn inside (and over) the focus ring.


<!-- sorting key: programs.niri.settings.l.layout.a.border.a.enable -->
## `programs.niri.settings.layout.border.enable`
- type: `boolean`
- default: `false`

Whether to enable the border.


<!-- sorting key: programs.niri.settings.l.layout.a.border.a.width -->
## `programs.niri.settings.layout.border.width`
- type: `floating point number or signed integer`
- default: `4`

The width of the border drawn around each window.


<!-- sorting key: programs.niri.settings.l.layout.a.border.b.active -->
## `programs.niri.settings.layout.border.active`
- type: [`<decoration>`](#decoration), which is a `variant of: color | gradient`
- default:
  ```nix
  {
    color = "rgb(255 200 127)";
  }
  ```


The color of the border for the window that has keyboard focus.


<!-- sorting key: programs.niri.settings.l.layout.a.border.b.inactive -->
## `programs.niri.settings.layout.border.inactive`
- type: [`<decoration>`](#decoration), which is a `variant of: color | gradient`
- default:
  ```nix
  {
    color = "rgb(80 80 80)";
  }
  ```


The color of the border for windows that do not have keyboard focus.


<!-- sorting key: programs.niri.settings.l.layout.a.focus-ring -->
## `programs.niri.settings.layout.focus-ring`


The focus ring is a decoration drawn *around* the last focused window on each monitor. It takes no space away from windows. If you have insufficient gaps, the focus ring can be drawn over adjacent windows, but it will never affect the layout of windows.

The focused window of the currently focused monitor, i.e. the window that can receive keyboard input, will be drawn according to [`layout.focus-ring.active`](#programsnirisettingslayoutfocus-ringactive), and the last focused window on all other monitors will be drawn according to [`layout.focus-ring.inactive`](#programsnirisettingslayoutfocus-ringinactive).

If you have [`layout.border`](#programsnirisettingslayoutborder) enabled, the focus ring will be drawn around (and under) the border.


<!-- sorting key: programs.niri.settings.l.layout.a.focus-ring.a.enable -->
## `programs.niri.settings.layout.focus-ring.enable`
- type: `boolean`
- default: `true`

Whether to enable the focus ring.


<!-- sorting key: programs.niri.settings.l.layout.a.focus-ring.a.width -->
## `programs.niri.settings.layout.focus-ring.width`
- type: `floating point number or signed integer`
- default: `4`

The width of the focus ring drawn around each focused window.


<!-- sorting key: programs.niri.settings.l.layout.a.focus-ring.b.active -->
## `programs.niri.settings.layout.focus-ring.active`
- type: [`<decoration>`](#decoration), which is a `variant of: color | gradient`
- default:
  ```nix
  {
    color = "rgb(127 200 255)";
  }
  ```


The color of the focus ring for the window that has keyboard focus.


<!-- sorting key: programs.niri.settings.l.layout.a.focus-ring.b.inactive -->
## `programs.niri.settings.layout.focus-ring.inactive`
- type: [`<decoration>`](#decoration), which is a `variant of: color | gradient`
- default:
  ```nix
  {
    color = "rgb(80 80 80)";
  }
  ```


The color of the focus ring for windows that do not have keyboard focus.


<!-- sorting key: programs.niri.settings.l.layout.b.shadow -->
<!-- programs.niri.settings.layout.shadow -->

<!-- sorting key: programs.niri.settings.l.layout.b.shadow.color -->
## `programs.niri.settings.layout.shadow.color`
- type: `string`
- default: `"#00000070"`


<!-- sorting key: programs.niri.settings.l.layout.b.shadow.draw-behind-window -->
## `programs.niri.settings.layout.shadow.draw-behind-window`
- type: `boolean`
- default: `false`


<!-- sorting key: programs.niri.settings.l.layout.b.shadow.enable -->
## `programs.niri.settings.layout.shadow.enable`
- type: `boolean`
- default: `false`


<!-- sorting key: programs.niri.settings.l.layout.b.shadow.inactive-color -->
## `programs.niri.settings.layout.shadow.inactive-color`
- type: `null or string`
- default: `null`


<!-- sorting key: programs.niri.settings.l.layout.b.shadow.offset -->
## `programs.niri.settings.layout.shadow.offset`


The offset of the shadow from the window, measured in logical pixels.

This behaves like a [CSS box-shadow offset](https://developer.mozilla.org/en-US/docs/Web/CSS/box-shadow#syntax)


<!-- sorting key: programs.niri.settings.l.layout.b.shadow.offset.x -->
## `programs.niri.settings.layout.shadow.offset.x`
- type: `floating point number or signed integer`
- default: `0.000000`


<!-- sorting key: programs.niri.settings.l.layout.b.shadow.offset.y -->
## `programs.niri.settings.layout.shadow.offset.y`
- type: `floating point number or signed integer`
- default: `5.000000`


<!-- sorting key: programs.niri.settings.l.layout.b.shadow.softness -->
## `programs.niri.settings.layout.shadow.softness`
- type: `floating point number or signed integer`
- default: `30.000000`

The softness/size of the shadow, measured in logical pixels.

This behaves like a [CSS box-shadow blur-radius](https://developer.mozilla.org/en-US/docs/Web/CSS/box-shadow#syntax)


<!-- sorting key: programs.niri.settings.l.layout.b.shadow.spread -->
## `programs.niri.settings.layout.shadow.spread`
- type: `floating point number or signed integer`
- default: `5.000000`

The spread of the shadow, measured in logical pixels.

This behaves like a [CSS box-shadow spread radius](https://developer.mozilla.org/en-US/docs/Web/CSS/box-shadow#syntax)


<!-- sorting key: programs.niri.settings.l.layout.c.insert-hint -->
## `programs.niri.settings.layout.insert-hint`


The insert hint is a decoration drawn *between* windows during an interactive move operation. It is drawn in the gap where the window will be inserted when you release the window. It does not occupy any space in the gap, and the insert hint extends onto the edges of adjacent windows. When you release the moved window, the windows that are covered by the insert hint will be pushed aside to make room for the moved window.


<!-- sorting key: programs.niri.settings.l.layout.c.insert-hint.a.enable -->
## `programs.niri.settings.layout.insert-hint.enable`
- type: `boolean`
- default: `true`

Whether to enable the insert hint.


<!-- sorting key: programs.niri.settings.l.layout.c.insert-hint.b.display -->
## `programs.niri.settings.layout.insert-hint.display`
- type: [`<decoration>`](#decoration), which is a `variant of: color | gradient`
- default:
  ```nix
  {
    color = "rgb(127 200 255 / 50%)";
  }
  ```


The color of the insert hint.


<!-- sorting key: programs.niri.settings.l.layout.d.decoration -->
## `<decoration>`
- type: `variant of: color | gradient`

A decoration is drawn around a surface, adding additional elements that are not necessarily part of an application, but are part of what we think of as a "window".

This type specifically represents decorations drawn by niri: that is, [`layout.focus-ring`](#programsnirisettingslayoutfocus-ring) and/or [`layout.border`](#programsnirisettingslayoutborder).




<!-- sorting key: programs.niri.settings.l.layout.d.decoration.color -->
## `<decoration>.color`
- type: `string`

A solid color to use for the decoration.

This is a CSS [`<color>`](https://developer.mozilla.org/en-US/docs/Web/CSS/color_value) value, like `"rgb(255 0 0)"`, `"#C0FFEE"`, or `"sandybrown"`.

The specific crate that niri uses to parse this also supports some nonstandard color functions, like `hwba()`, `hsv()`, `hsva()`. See [`csscolorparser`](https://crates.io/crates/csscolorparser) for details.


<!-- sorting key: programs.niri.settings.l.layout.d.decoration.gradient -->
## `<decoration>.gradient`
- type: `gradient`

A linear gradient to use for the decoration.

This is meant to approximate the CSS [`linear-gradient()`](https://developer.mozilla.org/en-US/docs/Web/CSS/gradient/linear-gradient) function, but niri does not fully support all the same parameters. Only an angle in degrees is supported.


<!-- sorting key: programs.niri.settings.l.layout.d.decoration.gradient.angle -->
## `<decoration>.gradient.angle`
- type: `signed integer`
- default: `180`

The angle of the gradient, in degrees, measured clockwise from a gradient that starts at the bottom and ends at the top.

This is the same as the angle parameter in the CSS [`linear-gradient()`](https://developer.mozilla.org/en-US/docs/Web/CSS/gradient/linear-gradient) function, except you can only express it in degrees.


<!-- sorting key: programs.niri.settings.l.layout.d.decoration.gradient.from -->
## `<decoration>.gradient.from`
- type: `string`

The starting [`<color>`](https://developer.mozilla.org/en-US/docs/Web/CSS/color_value) of the gradient.

For more details, see [`<decoration>.color`](#decorationcolor).


<!-- sorting key: programs.niri.settings.l.layout.d.decoration.gradient.in' -->
## `<decoration>.gradient.in'`
- type: `null or one of "srgb", "srgb-linear", "oklab", "oklch shorter hue", "oklch longer hue", "oklch increasing hue", "oklch decreasing hue"`
- default: `null`

The colorspace to interpolate the gradient in. This option is named `in'` because `in` is a reserved keyword in Nix.

This is a subset of the [`<color-interpolation-method>`](https://developer.mozilla.org/en-US/docs/Web/CSS/color-interpolation-method) values in CSS.


<!-- sorting key: programs.niri.settings.l.layout.d.decoration.gradient.relative-to -->
## `<decoration>.gradient.relative-to`
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


<!-- sorting key: programs.niri.settings.l.layout.d.decoration.gradient.to -->
## `<decoration>.gradient.to`
- type: `string`

The ending [`<color>`](https://developer.mozilla.org/en-US/docs/Web/CSS/color_value) of the gradient.

For more details, see [`<decoration>.color`](#decorationcolor).


<!-- sorting key: programs.niri.settings.l.layout.e.background-color -->
## `programs.niri.settings.layout.background-color`
- type: `null or string`
- default: `null`

The default background color that niri draws for workspaces. This is visible when you're not using any background tools like swaybg.


<!-- sorting key: programs.niri.settings.l.layout.f.preset-column-widths -->
## `programs.niri.settings.layout.preset-column-widths`
- type: `list of variant of: fixed | proportion`

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


<!-- sorting key: programs.niri.settings.l.layout.f.preset-column-widths.fixed -->
## `programs.niri.settings.layout.preset-column-widths.*.fixed`
- type: `signed integer`

The width of the column in logical pixels


<!-- sorting key: programs.niri.settings.l.layout.f.preset-column-widths.proportion -->
## `programs.niri.settings.layout.preset-column-widths.*.proportion`
- type: `floating point number`

The width of the column as a proportion of the screen's width


<!-- sorting key: programs.niri.settings.l.layout.f.preset-window-heights -->
## `programs.niri.settings.layout.preset-window-heights`
- type: `list of variant of: fixed | proportion`

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


<!-- sorting key: programs.niri.settings.l.layout.f.preset-window-heights.fixed -->
## `programs.niri.settings.layout.preset-window-heights.*.fixed`
- type: `signed integer`

The height of the window in logical pixels


<!-- sorting key: programs.niri.settings.l.layout.f.preset-window-heights.proportion -->
## `programs.niri.settings.layout.preset-window-heights.*.proportion`
- type: `floating point number`

The height of the window as a proportion of the screen's height


<!-- sorting key: programs.niri.settings.l.layout.g.always-center-single-column -->
## `programs.niri.settings.layout.always-center-single-column`
- type: `boolean`
- default: `false`

This is like `center-focused-column = "always";`, but only for workspaces with a single column. Changes nothing is `center-focused-column` is set to `"always"`. Has no effect if more than one column is present.


<!-- sorting key: programs.niri.settings.l.layout.g.center-focused-column -->
## `programs.niri.settings.layout.center-focused-column`
- type: `one of "never", "always", "on-overflow"`
- default: `"never"`

When changing focus, niri can automatically center the focused column.

- `"never"`: If the focused column doesn't fit, it will be aligned to the edges of the screen.
- `"on-overflow"`: if the focused column doesn't fit, it will be centered on the screen.
- `"always"`: the focused column will always be centered, even if it was already fully visible.


<!-- sorting key: programs.niri.settings.l.layout.g.default-column-display -->
## `programs.niri.settings.layout.default-column-display`
- type: `one of "normal", "tabbed"`
- default: `"normal"`

How windows in columns should be displayed by default.

- `"normal"`: Windows are arranged vertically, spread across the working area height.
- `"tabbed"`: Windows are arranged in tabs, with only the focused window visible, taking up the full height of the working area.

Note that you can override this for a given column at any time. Every column remembers its own display mode, independent from this setting. This setting controls the default value when a column is *created*.

Also, since a newly created column always contains a single window, you can override this default value with [`window-rules.*.default-column-display`](#programsnirisettingswindow-rulesdefault-column-display).


<!-- sorting key: programs.niri.settings.l.layout.g.default-column-width -->
## `programs.niri.settings.layout.default-column-width`
- type: `{} or (variant of: fixed | proportion)`

The default width for new columns.

When this is set to an empty attrset `{}`, windows will get to decide their initial width. This is not null, such that it can be distinguished from window rules that don't touch this

See [`layout.preset-column-widths`](#programsnirisettingslayoutpreset-column-widths) for more information.

You can override this for specific windows using [`window-rules.*.default-column-width`](#programsnirisettingswindow-rulesdefault-column-width)


<!-- sorting key: programs.niri.settings.l.layout.g.default-column-width.fixed -->
## `programs.niri.settings.layout.default-column-width.fixed`
- type: `signed integer`

The width of the column in logical pixels


<!-- sorting key: programs.niri.settings.l.layout.g.default-column-width.proportion -->
## `programs.niri.settings.layout.default-column-width.proportion`
- type: `floating point number`

The width of the column as a proportion of the screen's width


<!-- sorting key: programs.niri.settings.l.layout.g.tab-indicator -->
## `programs.niri.settings.layout.tab-indicator`
- type: `null or (submodule)`
- default: `null`


<!-- sorting key: programs.niri.settings.l.layout.g.tab-indicator.a.corner-radius -->
## `programs.niri.settings.layout.tab-indicator.corner-radius`
- type: `floating point number or signed integer`
- default: `0.000000`


<!-- sorting key: programs.niri.settings.l.layout.g.tab-indicator.a.enable -->
## `programs.niri.settings.layout.tab-indicator.enable`
- type: `boolean`
- default: `true`


<!-- sorting key: programs.niri.settings.l.layout.g.tab-indicator.a.gap -->
## `programs.niri.settings.layout.tab-indicator.gap`
- type: `floating point number or signed integer`
- default: `5.000000`


<!-- sorting key: programs.niri.settings.l.layout.g.tab-indicator.a.gaps-between-tabs -->
## `programs.niri.settings.layout.tab-indicator.gaps-between-tabs`
- type: `floating point number or signed integer`
- default: `0.000000`


<!-- sorting key: programs.niri.settings.l.layout.g.tab-indicator.a.hide-when-single-tab -->
## `programs.niri.settings.layout.tab-indicator.hide-when-single-tab`
- type: `boolean`
- default: `false`


<!-- sorting key: programs.niri.settings.l.layout.g.tab-indicator.a.length.total-proportion -->
## `programs.niri.settings.layout.tab-indicator.length.total-proportion`
- type: `floating point number`
- default: `0.500000`


<!-- sorting key: programs.niri.settings.l.layout.g.tab-indicator.a.place-within-column -->
## `programs.niri.settings.layout.tab-indicator.place-within-column`
- type: `boolean`
- default: `false`


<!-- sorting key: programs.niri.settings.l.layout.g.tab-indicator.a.position -->
## `programs.niri.settings.layout.tab-indicator.position`
- type: `one of "left", "right", "top", "bottom"`
- default: `"left"`


<!-- sorting key: programs.niri.settings.l.layout.g.tab-indicator.a.width -->
## `programs.niri.settings.layout.tab-indicator.width`
- type: `floating point number or signed integer`
- default: `4.000000`


<!-- sorting key: programs.niri.settings.l.layout.g.tab-indicator.b.active -->
## `programs.niri.settings.layout.tab-indicator.active`
- type: [`<decoration>`](#decoration), which is a `variant of: color | gradient`
- default: `config.programs.niri.settings.layout.border.active`

The color of the tab indicator for the window that has keyboard focus.


<!-- sorting key: programs.niri.settings.l.layout.g.tab-indicator.b.inactive -->
## `programs.niri.settings.layout.tab-indicator.inactive`
- type: [`<decoration>`](#decoration), which is a `variant of: color | gradient`
- default: `config.programs.niri.settings.layout.border.inactive`

The color of the the tab indicator for windows that do not have keyboard focus.


<!-- sorting key: programs.niri.settings.l.layout.h.empty-workspace-above-first -->
## `programs.niri.settings.layout.empty-workspace-above-first`
- type: `boolean`
- default: `false`

Normally, niri has a dynamic amount of workspaces, with one empty workspace at the end. The first workspace really  is the first workspace, and you cannot go past it, but going past the last workspace puts you on the empty workspace.

When this is enabled, there will be an empty workspace above the first workspace, and you can go past the first workspace to get to an empty workspace, just as in the other direction. This makes workspace navigation symmetric in all ways except indexing.


<!-- sorting key: programs.niri.settings.l.layout.h.gaps -->
## `programs.niri.settings.layout.gaps`
- type: `floating point number or signed integer`
- default: `16`

The gap between windows in the layout, measured in logical pixels.


<!-- sorting key: programs.niri.settings.l.layout.h.struts -->
## `programs.niri.settings.layout.struts`


The distances from the edges of the screen to the eges of the working area.

The top and bottom struts are absolute gaps from the edges of the screen. If you set a bottom strut of 64px and the scale is 2.0, then the output will have 128 physical pixels under the scrollable working area where it only shows the wallpaper.

Struts are computed in addition to layer-shell surfaces. If you have a waybar of 32px at the top, and you set a top strut of 16px, then you will have 48 logical pixels from the actual edge of the display to the top of the working area.

The left and right structs work in a similar way, except the padded space is not empty. The horizontal struts are used to constrain where focused windows are allowed to go. If you define a left strut of 64px and go to the first window in a workspace, that window will be aligned 64 logical pixels from the left edge of the output, rather than snapping to the actual edge of the screen. If another window exists to the left of this window, then you will see 64px of its right edge (if you have zero borders and gaps)


<!-- sorting key: programs.niri.settings.l.layout.h.struts.bottom -->
## `programs.niri.settings.layout.struts.bottom`
- type: `floating point number or signed integer`
- default: `0`


<!-- sorting key: programs.niri.settings.l.layout.h.struts.left -->
## `programs.niri.settings.layout.struts.left`
- type: `floating point number or signed integer`
- default: `0`


<!-- sorting key: programs.niri.settings.l.layout.h.struts.right -->
## `programs.niri.settings.layout.struts.right`
- type: `floating point number or signed integer`
- default: `0`


<!-- sorting key: programs.niri.settings.l.layout.h.struts.top -->
## `programs.niri.settings.layout.struts.top`
- type: `floating point number or signed integer`
- default: `0`


<!-- sorting key: programs.niri.settings.m.animations -->
<!-- programs.niri.settings.animations -->

<!-- sorting key: programs.niri.settings.m.animations.a.enable -->
## `programs.niri.settings.animations.enable`
- type: `boolean`
- default: `true`


<!-- sorting key: programs.niri.settings.m.animations.a.slowdown -->
## `programs.niri.settings.animations.slowdown`
- type: `null or floating point number`
- default: `null`


<!-- sorting key: programs.niri.settings.m.animations.c.config-notification-open-close -->
<!-- programs.niri.settings.animations.config-notification-open-close -->

<!-- sorting key: programs.niri.settings.m.animations.c.config-notification-open-close.enable -->
## `programs.niri.settings.animations.config-notification-open-close.enable`
- type: `boolean`
- default: `true`


<!-- sorting key: programs.niri.settings.m.animations.c.config-notification-open-close.kind -->
## `programs.niri.settings.animations.config-notification-open-close.kind`
- type: [`<animation-kind>`](#animation-kind), which is a `null or (variant of: easing | spring)`
- default: `null`


<!-- sorting key: programs.niri.settings.m.animations.c.horizontal-view-movement -->
<!-- programs.niri.settings.animations.horizontal-view-movement -->

<!-- sorting key: programs.niri.settings.m.animations.c.horizontal-view-movement.enable -->
## `programs.niri.settings.animations.horizontal-view-movement.enable`
- type: `boolean`
- default: `true`


<!-- sorting key: programs.niri.settings.m.animations.c.horizontal-view-movement.kind -->
## `programs.niri.settings.animations.horizontal-view-movement.kind`
- type: [`<animation-kind>`](#animation-kind), which is a `null or (variant of: easing | spring)`
- default: `null`


<!-- sorting key: programs.niri.settings.m.animations.c.overview-open-close -->
<!-- programs.niri.settings.animations.overview-open-close -->

<!-- sorting key: programs.niri.settings.m.animations.c.overview-open-close.enable -->
## `programs.niri.settings.animations.overview-open-close.enable`
- type: `boolean`
- default: `true`


<!-- sorting key: programs.niri.settings.m.animations.c.overview-open-close.kind -->
## `programs.niri.settings.animations.overview-open-close.kind`
- type: [`<animation-kind>`](#animation-kind), which is a `null or (variant of: easing | spring)`
- default: `null`


<!-- sorting key: programs.niri.settings.m.animations.c.screenshot-ui-open -->
<!-- programs.niri.settings.animations.screenshot-ui-open -->

<!-- sorting key: programs.niri.settings.m.animations.c.screenshot-ui-open.enable -->
## `programs.niri.settings.animations.screenshot-ui-open.enable`
- type: `boolean`
- default: `true`


<!-- sorting key: programs.niri.settings.m.animations.c.screenshot-ui-open.kind -->
## `programs.niri.settings.animations.screenshot-ui-open.kind`
- type: [`<animation-kind>`](#animation-kind), which is a `null or (variant of: easing | spring)`
- default: `null`


<!-- sorting key: programs.niri.settings.m.animations.c.window-close -->
<!-- programs.niri.settings.animations.window-close -->

<!-- sorting key: programs.niri.settings.m.animations.c.window-close.custom-shader -->
## `programs.niri.settings.animations.window-close.custom-shader`
- type: `null or string`
- default: `null`

Source code for a GLSL shader to use for this animation.

For example, set it to `builtins.readFile ./window-close.glsl` to use a shader from the same directory as your configuration file.

See: https://github.com/YaLTeR/niri/wiki/Configuration:-Animations#custom-shader


<!-- sorting key: programs.niri.settings.m.animations.c.window-close.enable -->
## `programs.niri.settings.animations.window-close.enable`
- type: `boolean`
- default: `true`


<!-- sorting key: programs.niri.settings.m.animations.c.window-close.kind -->
## `programs.niri.settings.animations.window-close.kind`
- type: [`<animation-kind>`](#animation-kind), which is a `null or (variant of: easing | spring)`
- default: `null`


<!-- sorting key: programs.niri.settings.m.animations.c.window-movement -->
<!-- programs.niri.settings.animations.window-movement -->

<!-- sorting key: programs.niri.settings.m.animations.c.window-movement.enable -->
## `programs.niri.settings.animations.window-movement.enable`
- type: `boolean`
- default: `true`


<!-- sorting key: programs.niri.settings.m.animations.c.window-movement.kind -->
## `programs.niri.settings.animations.window-movement.kind`
- type: [`<animation-kind>`](#animation-kind), which is a `null or (variant of: easing | spring)`
- default: `null`


<!-- sorting key: programs.niri.settings.m.animations.c.window-open -->
<!-- programs.niri.settings.animations.window-open -->

<!-- sorting key: programs.niri.settings.m.animations.c.window-open.custom-shader -->
## `programs.niri.settings.animations.window-open.custom-shader`
- type: `null or string`
- default: `null`

Source code for a GLSL shader to use for this animation.

For example, set it to `builtins.readFile ./window-open.glsl` to use a shader from the same directory as your configuration file.

See: https://github.com/YaLTeR/niri/wiki/Configuration:-Animations#custom-shader


<!-- sorting key: programs.niri.settings.m.animations.c.window-open.enable -->
## `programs.niri.settings.animations.window-open.enable`
- type: `boolean`
- default: `true`


<!-- sorting key: programs.niri.settings.m.animations.c.window-open.kind -->
## `programs.niri.settings.animations.window-open.kind`
- type: [`<animation-kind>`](#animation-kind), which is a `null or (variant of: easing | spring)`
- default: `null`


<!-- sorting key: programs.niri.settings.m.animations.c.window-resize -->
<!-- programs.niri.settings.animations.window-resize -->

<!-- sorting key: programs.niri.settings.m.animations.c.window-resize.custom-shader -->
## `programs.niri.settings.animations.window-resize.custom-shader`
- type: `null or string`
- default: `null`

Source code for a GLSL shader to use for this animation.

For example, set it to `builtins.readFile ./window-resize.glsl` to use a shader from the same directory as your configuration file.

See: https://github.com/YaLTeR/niri/wiki/Configuration:-Animations#custom-shader


<!-- sorting key: programs.niri.settings.m.animations.c.window-resize.enable -->
## `programs.niri.settings.animations.window-resize.enable`
- type: `boolean`
- default: `true`


<!-- sorting key: programs.niri.settings.m.animations.c.window-resize.kind -->
## `programs.niri.settings.animations.window-resize.kind`
- type: [`<animation-kind>`](#animation-kind), which is a `null or (variant of: easing | spring)`
- default: `null`


<!-- sorting key: programs.niri.settings.m.animations.c.workspace-switch -->
<!-- programs.niri.settings.animations.workspace-switch -->

<!-- sorting key: programs.niri.settings.m.animations.c.workspace-switch.enable -->
## `programs.niri.settings.animations.workspace-switch.enable`
- type: `boolean`
- default: `true`


<!-- sorting key: programs.niri.settings.m.animations.c.workspace-switch.kind -->
## `programs.niri.settings.animations.workspace-switch.kind`
- type: [`<animation-kind>`](#animation-kind), which is a `null or (variant of: easing | spring)`
- default: `null`


<!-- sorting key: programs.niri.settings.m.animations.d.<animation-kind> -->
## `<animation-kind>`
- type: `variant of: easing | spring`


<!-- sorting key: programs.niri.settings.m.animations.d.<animation-kind>.easing -->
<!-- <animation-kind>.easing -->

<!-- sorting key: programs.niri.settings.m.animations.d.<animation-kind>.easing.curve -->
## `<animation-kind>.easing.curve`
- type: `one of "linear", "ease-out-quad", "ease-out-cubic", "ease-out-expo"`

The curve to use for the easing function.


<!-- sorting key: programs.niri.settings.m.animations.d.<animation-kind>.easing.duration-ms -->
## `<animation-kind>.easing.duration-ms`
- type: `signed integer`


<!-- sorting key: programs.niri.settings.m.animations.d.<animation-kind>.spring -->
<!-- <animation-kind>.spring -->

<!-- sorting key: programs.niri.settings.m.animations.d.<animation-kind>.spring.damping-ratio -->
## `<animation-kind>.spring.damping-ratio`
- type: `floating point number`


<!-- sorting key: programs.niri.settings.m.animations.d.<animation-kind>.spring.epsilon -->
## `<animation-kind>.spring.epsilon`
- type: `floating point number`


<!-- sorting key: programs.niri.settings.m.animations.d.<animation-kind>.spring.stiffness -->
## `<animation-kind>.spring.stiffness`
- type: `signed integer`


<!-- sorting key: programs.niri.settings.m.gestures.dnd-edge-view-scroll -->
## `programs.niri.settings.gestures.dnd-edge-view-scroll`


When dragging a window to the left or right edge of the screen, the view will start scrolling in that direction.


<!-- sorting key: programs.niri.settings.m.gestures.dnd-edge-view-scroll.delay-ms -->
## `programs.niri.settings.gestures.dnd-edge-view-scroll.delay-ms`
- type: `null or signed integer`
- default: `null`

The delay in milliseconds before the view starts scrolling.


<!-- sorting key: programs.niri.settings.m.gestures.dnd-edge-view-scroll.max-speed -->
## `programs.niri.settings.gestures.dnd-edge-view-scroll.max-speed`
- type: `null or floating point number or signed integer`
- default: `null`

When the cursor is at boundary of the trigger width, the view will not be scrolling. Moving the mouse further away from the boundary and closer to the egde will linearly increase the scrolling speed, until the mouse is pressed against the edge of the screen, at which point the view will scroll at this speed. The speed is measured in logical pixels per second.


<!-- sorting key: programs.niri.settings.m.gestures.dnd-edge-view-scroll.trigger-width -->
## `programs.niri.settings.gestures.dnd-edge-view-scroll.trigger-width`
- type: `null or floating point number or signed integer`
- default: `null`

The width of the edge of the screen where dragging a window will scroll the view.


<!-- sorting key: programs.niri.settings.m.gestures.dnd-edge-workspace-switch -->
## `programs.niri.settings.gestures.dnd-edge-workspace-switch`


In the overview, when dragging a window to the top or bottom edge of the screen, view will start scrolling in that direction.

This does not happen when the overview is not open.


<!-- sorting key: programs.niri.settings.m.gestures.dnd-edge-workspace-switch.delay-ms -->
## `programs.niri.settings.gestures.dnd-edge-workspace-switch.delay-ms`
- type: `null or signed integer`
- default: `null`

The delay in milliseconds before the view starts scrolling.


<!-- sorting key: programs.niri.settings.m.gestures.dnd-edge-workspace-switch.max-speed -->
## `programs.niri.settings.gestures.dnd-edge-workspace-switch.max-speed`
- type: `null or floating point number or signed integer`
- default: `null`

When the cursor is at boundary of the trigger height, the view will not be scrolling. Moving the mouse further away from the boundary and closer to the egde will linearly increase the scrolling speed, until the mouse is pressed against the edge of the screen, at which point the view will scroll at this speed. The speed is measured in logical pixels per second.


<!-- sorting key: programs.niri.settings.m.gestures.dnd-edge-workspace-switch.trigger-height -->
## `programs.niri.settings.gestures.dnd-edge-workspace-switch.trigger-height`
- type: `null or floating point number or signed integer`
- default: `null`

The height of the edge of the screen where dragging a window will scroll the view.


<!-- sorting key: programs.niri.settings.m.gestures.hot-corners.enable -->
## `programs.niri.settings.gestures.hot-corners.enable`
- type: `boolean`
- default: `true`

Put your mouse at the very top-left corner of a monitor to toggle the overview. Also works during drag-and-dropping something.


<!-- sorting key: programs.niri.settings.n.environment -->
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


<!-- sorting key: programs.niri.settings.o.window-rules -->
## `programs.niri.settings.window-rules`
- type: `list of window rule`

Window rules.

A window rule will match based on [`window-rules.*.matches`](#programsnirisettingswindow-rulesmatches) and [`window-rules.*.excludes`](#programsnirisettingswindow-rulesexcludes). Both of these are lists of "match rules".

A given match rule can match based on one of several fields. For a given match rule to "match" a window, it must match on all fields.

- The `title` field, when non-null, is a regular expression. It will match a window if the client has set a title and its title matches the regular expression.

- The `app-id` field, when non-null, is a regular expression. It will match a window if the client has set an app id and its app id matches the regular expression.


- The `at_startup` field, when non-null, will match a window based on whether it was opened within the first 60 seconds of niri starting up.

- If a field is null, it will always match.

For a given window rule to match a window, the above logic is employed to determine whether any given match rule matches, and the interactions between the match rules decide whether the window rule as a whole will match. For a given window rule:

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


<!-- sorting key: programs.niri.settings.o.window-rules.a.matches -->
## `programs.niri.settings.window-rules.*.matches`
- type: `list of match rule`

A list of rules to match windows.

If any of these rules match a window (or there are none), that window rule will be considered for this window. It can still be rejected by [`window-rules.*.excludes`](#programsnirisettingswindow-rulesexcludes)

If all of the rules do not match a window, then this window rule will not apply to that window.


<!-- sorting key: programs.niri.settings.o.window-rules.a.matches.a.app-id -->
## `programs.niri.settings.window-rules.*.matches.*.app-id`
- type: `null or regular expression`
- default: `null`

A regular expression to match against the app id of the window.

When non-null, for this field to match a window, a client must set the app id of its window and the app id must match this regex.


<!-- sorting key: programs.niri.settings.o.window-rules.a.matches.a.title -->
## `programs.niri.settings.window-rules.*.matches.*.title`
- type: `null or regular expression`
- default: `null`

A regular expression to match against the title of the window.

When non-null, for this field to match a window, a client must set the title of its window and the title must match this regex.


<!-- sorting key: programs.niri.settings.o.window-rules.a.matches.b.is-active -->
## `programs.niri.settings.window-rules.*.matches.*.is-active`
- type: `null or boolean`
- default: `null`

When non-null, for this field to match a window, the value must match whether the window is active or not.

Every monitor has up to one active window, and `is-active=true` will match the active window on each monitor. A monitor can have zero active windows if no windows are open on it. There can never be more than one active window on a monitor.


<!-- sorting key: programs.niri.settings.o.window-rules.a.matches.b.is-active-in-column -->
## `programs.niri.settings.window-rules.*.matches.*.is-active-in-column`
- type: `null or boolean`
- default: `null`

When non-null, for this field to match a window, the value must match whether the window is active in its column or not.

Every column has exactly one active-in-column window. If it is the active column, this window is also the active window. A column may not have zero active-in-column windows, or more than one active-in-column window.

The active-in-column window is the window that was last focused in that column. When you switch focus to a column, the active-in-column window will be the new focused window.


<!-- sorting key: programs.niri.settings.o.window-rules.a.matches.b.is-floating -->
## `programs.niri.settings.window-rules.*.matches.*.is-floating`
- type: `null or boolean`
- default: `null`

When not-null, for this field to match a window, the value must match whether the window is floating (true) or tiled (false).


<!-- sorting key: programs.niri.settings.o.window-rules.a.matches.b.is-focused -->
## `programs.niri.settings.window-rules.*.matches.*.is-focused`
- type: `null or boolean`
- default: `null`

When non-null, for this field to match a window, the value must match whether the window has keyboard focus or not.

A note on terminology used here: a window is actually a toplevel surface, and a surface just refers to any rectangular region that a client can draw to. A toplevel surface is just a surface with additional capabilities and properties (e.g. "fullscreen", "resizable", "min size", etc)

For a window to be focused, its surface must be focused. There is up to one focused surface, and it is the surface that can receive keyboard input. There can never be more than one focused surface. There can be zero focused surfaces if and only if there are zero surfaces. The focused surface does *not* have to be a toplevel surface. It can also be a layer-shell surface. In that case, there is a surface with keyboard focus but no *window* with keyboard focus.


<!-- sorting key: programs.niri.settings.o.window-rules.a.matches.b.is-window-cast-target -->
## `programs.niri.settings.window-rules.*.matches.*.is-window-cast-target`
- type: `null or boolean`
- default: `null`

When non-null, matches based on whether the window is being targeted by a window cast.


<!-- sorting key: programs.niri.settings.o.window-rules.a.matches.c.at-startup -->
## `programs.niri.settings.window-rules.*.matches.*.at-startup`
- type: `null or boolean`
- default: `null`

When true, this rule will match windows opened within the first 60 seconds of niri starting up. When false, this rule will match windows opened *more than* 60 seconds after niri started up. This is useful for applying different rules to windows opened from [`spawn-at-startup`](#programsnirisettingsspawn-at-startup) versus those opened later.


<!-- sorting key: programs.niri.settings.o.window-rules.b.excludes -->
## `programs.niri.settings.window-rules.*.excludes`
- type: `list of match rule`

A list of rules to exclude windows.

If any of these rules match a window, then this window rule will not apply to that window, even if it matches one of the rules in [`window-rules.*.matches`](#programsnirisettingswindow-rulesmatches)

If none of these rules match a window, then this window rule will not be rejected. It will apply to that window if and only if it matches one of the rules in [`window-rules.*.matches`](#programsnirisettingswindow-rulesmatches)


<!-- sorting key: programs.niri.settings.o.window-rules.b.excludes.a.app-id -->
## `programs.niri.settings.window-rules.*.excludes.*.app-id`
- type: `null or regular expression`
- default: `null`

A regular expression to match against the app id of the window.

When non-null, for this field to match a window, a client must set the app id of its window and the app id must match this regex.


<!-- sorting key: programs.niri.settings.o.window-rules.b.excludes.a.title -->
## `programs.niri.settings.window-rules.*.excludes.*.title`
- type: `null or regular expression`
- default: `null`

A regular expression to match against the title of the window.

When non-null, for this field to match a window, a client must set the title of its window and the title must match this regex.


<!-- sorting key: programs.niri.settings.o.window-rules.b.excludes.b.is-active -->
## `programs.niri.settings.window-rules.*.excludes.*.is-active`
- type: `null or boolean`
- default: `null`

When non-null, for this field to match a window, the value must match whether the window is active or not.

Every monitor has up to one active window, and `is-active=true` will match the active window on each monitor. A monitor can have zero active windows if no windows are open on it. There can never be more than one active window on a monitor.


<!-- sorting key: programs.niri.settings.o.window-rules.b.excludes.b.is-active-in-column -->
## `programs.niri.settings.window-rules.*.excludes.*.is-active-in-column`
- type: `null or boolean`
- default: `null`

When non-null, for this field to match a window, the value must match whether the window is active in its column or not.

Every column has exactly one active-in-column window. If it is the active column, this window is also the active window. A column may not have zero active-in-column windows, or more than one active-in-column window.

The active-in-column window is the window that was last focused in that column. When you switch focus to a column, the active-in-column window will be the new focused window.


<!-- sorting key: programs.niri.settings.o.window-rules.b.excludes.b.is-floating -->
## `programs.niri.settings.window-rules.*.excludes.*.is-floating`
- type: `null or boolean`
- default: `null`

When not-null, for this field to match a window, the value must match whether the window is floating (true) or tiled (false).


<!-- sorting key: programs.niri.settings.o.window-rules.b.excludes.b.is-focused -->
## `programs.niri.settings.window-rules.*.excludes.*.is-focused`
- type: `null or boolean`
- default: `null`

When non-null, for this field to match a window, the value must match whether the window has keyboard focus or not.

A note on terminology used here: a window is actually a toplevel surface, and a surface just refers to any rectangular region that a client can draw to. A toplevel surface is just a surface with additional capabilities and properties (e.g. "fullscreen", "resizable", "min size", etc)

For a window to be focused, its surface must be focused. There is up to one focused surface, and it is the surface that can receive keyboard input. There can never be more than one focused surface. There can be zero focused surfaces if and only if there are zero surfaces. The focused surface does *not* have to be a toplevel surface. It can also be a layer-shell surface. In that case, there is a surface with keyboard focus but no *window* with keyboard focus.


<!-- sorting key: programs.niri.settings.o.window-rules.b.excludes.b.is-window-cast-target -->
## `programs.niri.settings.window-rules.*.excludes.*.is-window-cast-target`
- type: `null or boolean`
- default: `null`

When non-null, matches based on whether the window is being targeted by a window cast.


<!-- sorting key: programs.niri.settings.o.window-rules.b.excludes.c.at-startup -->
## `programs.niri.settings.window-rules.*.excludes.*.at-startup`
- type: `null or boolean`
- default: `null`

When true, this rule will match windows opened within the first 60 seconds of niri starting up. When false, this rule will match windows opened *more than* 60 seconds after niri started up. This is useful for applying different rules to windows opened from [`spawn-at-startup`](#programsnirisettingsspawn-at-startup) versus those opened later.


<!-- sorting key: programs.niri.settings.o.window-rules.c.default-column-display -->
## `programs.niri.settings.window-rules.*.default-column-display`
- type: `null or one of "normal", "tabbed"`
- default: `null`

When this window is inserted into the tiling layout such that a new column is created (e.g. when it is first opened, when it is expelled from an existing column, when it's moved to a new workspace, etc), this setting controls the default display mode of the column.

If the final value of this field is null, then the default display mode is taken from [`layout.default-column-display`](#programsnirisettingslayoutdefault-column-display).


<!-- sorting key: programs.niri.settings.o.window-rules.c.default-column-width -->
## `programs.niri.settings.window-rules.*.default-column-width`
- type: `null or {} or (variant of: fixed | proportion)`
- default: `null`

The default width for new columns.

If the final value of this option is null, it default to [`layout.default-column-width`](#programsnirisettingslayoutdefault-column-width)

If the final value option is not null, then its value will take priority over [`layout.default-column-width`](#programsnirisettingslayoutdefault-column-width) for windows matching this rule.

An empty attrset `{}` is not the same as null. When this is set to an empty attrset `{}`, windows will get to decide their initial width. When set to null, it represents that this particular window rule has no effect on the default width (and it should instead be taken from an earlier rule or the global default).



<!-- sorting key: programs.niri.settings.o.window-rules.c.default-column-width.fixed -->
## `programs.niri.settings.window-rules.*.default-column-width.fixed`
- type: `signed integer`

The width of the column in logical pixels


<!-- sorting key: programs.niri.settings.o.window-rules.c.default-column-width.proportion -->
## `programs.niri.settings.window-rules.*.default-column-width.proportion`
- type: `floating point number`

The width of the column as a proportion of the screen's width


<!-- sorting key: programs.niri.settings.o.window-rules.c.default-window-height -->
## `programs.niri.settings.window-rules.*.default-window-height`
- type: `null or {} or (variant of: fixed | proportion)`
- default: `null`

The default height for new floating windows.

This does nothing if the window is not floating when it is created.

There is no global default option for this in the layout section like for the column width. If the final value of this option is null, then it defaults to the empty attrset `{}`.

If this is set to an empty attrset `{}`, then it effectively "unsets" the default height for this window rule evaluation, as opposed to `null` which doesn't change the value at all. Future rules may still set it to a value and unset it again as they wish.

If the final value of this option is an empty attrset `{}`, then the client gets to decide the height of the window.

If the final value of this option is not an empty attrset `{}`, and the window spawns as floating, then the window will be created with the specified height.


<!-- sorting key: programs.niri.settings.o.window-rules.c.default-window-height.fixed -->
## `programs.niri.settings.window-rules.*.default-window-height.fixed`
- type: `signed integer`

The height of the window in logical pixels


<!-- sorting key: programs.niri.settings.o.window-rules.c.default-window-height.proportion -->
## `programs.niri.settings.window-rules.*.default-window-height.proportion`
- type: `floating point number`

The height of the window as a proportion of the screen's height


<!-- sorting key: programs.niri.settings.o.window-rules.d.open-floating -->
## `programs.niri.settings.window-rules.*.open-floating`
- type: `null or boolean`
- default: `null`

Whether to open this window as floating.

If the final value of this field is true, then this window will always be forced to open as floating.

If the final value of this field is false, then this window is never allowed to open as floating.

If the final value of this field is null, then niri will decide whether to open the window as floating or as tiled.


<!-- sorting key: programs.niri.settings.o.window-rules.d.open-focused -->
## `programs.niri.settings.window-rules.*.open-focused`
- type: `null or boolean`
- default: `null`

Whether to focus this window when it is opened.

If the final value of this field is null, then the window will be focused based on several factors:

- If it provided a valid activation token that hasn't expired, it will be focused.
- If the strict activation policy is enabled (not by default), the procedure ends here. It will be focused if and only if the activation token is valid.
- Otherwise, if no valid activation token was presented, but the window is a dialog, it will open next to its parent and be focused anyways.
- If the window is not a dialog, it will be focused if there is no fullscreen window; we don't want to steal its focus unless a dialog belongs to it.

(a dialog here means a toplevel surface that has a non-null parent)

If the final value of this field is not null, all of the above is ignored. Whether the window provides an activation token or not, doesn't matter. The window will be focused if and only if this field is true. If it is false, the window will not be focused, even if it provides a valid activation token.


<!-- sorting key: programs.niri.settings.o.window-rules.d.open-fullscreen -->
## `programs.niri.settings.window-rules.*.open-fullscreen`
- type: `null or boolean`
- default: `null`

Whether to open this window in fullscreen.

If the final value of this field is true, then this window will always be forced to open in fullscreen.

If the final value of this field is false, then this window is never allowed to open in fullscreen, even if it requests to do so.

If the final value of this field is null, then the client gets to decide if this window will open in fullscreen.


<!-- sorting key: programs.niri.settings.o.window-rules.d.open-maximized -->
## `programs.niri.settings.window-rules.*.open-maximized`
- type: `null or boolean`
- default: `null`

Whether to open this window in a maximized column.

If the final value of this field is null or false, then the window will not open in a maximized column.

If the final value of this field is true, then the window will open in a maximized column.


<!-- sorting key: programs.niri.settings.o.window-rules.d.open-on-output -->
## `programs.niri.settings.window-rules.*.open-on-output`
- type: `null or string`
- default: `null`

The output to open this window on.

If final value of this field is an output that exists, the new window will open on that output.

If the final value is an output that does not exist, or it is null, then the window opens on the currently focused output.


<!-- sorting key: programs.niri.settings.o.window-rules.d.open-on-workspace -->
## `programs.niri.settings.window-rules.*.open-on-workspace`
- type: `null or string`
- default: `null`

The workspace to open this window on.

If the final value of this field is a named workspace that exists, the window will open on that workspace.

If the final value of this is a named workspace that does not exist, or it is null, the window opens on the currently focused workspace.


<!-- sorting key: programs.niri.settings.o.window-rules.e.block-out-from -->
## `programs.niri.settings.window-rules.*.block-out-from`
- type: `null or one of "screencast", "screen-capture"`
- default: `null`

Whether to block out this window from screen captures. When the final value of this field is null, it is not blocked out from screen captures.

This is useful to protect sensitive information, like the contents of password managers or private chats. It is very important to understand the implications of this option, as described below, **especially if you are a streamer or content creator**.

Some of this may be obvious, but in general, these invariants *should* hold true:
- a window is never meant to be blocked out from the actual physical screen (otherwise you wouldn't be able to see it at all)
- a `block-out-from` window *is* meant to be always blocked out from screencasts (as they are often used for livestreaming etc)
- a `block-out-from` window is *not* supposed to be blocked from screenshots (because usually these are not broadcasted live, and you generally know what you're taking a screenshot of)

There are three methods of screencapture in niri:

1. The `org.freedesktop.portal.ScreenCast` interface, which is used by tools like OBS primarily to capture video. When `block-out-from = "screencast";` or `block-out-from = "screen-capture";`, this window is blocked out from the screencast portal, and will not be visible to screencasting software making use of the screencast portal.

1. The `wlr-screencopy` protocol, which is used by tools like `grim` primarily to capture screenshots. When `block-out-from = "screencast";`, this protocol is not affected and tools like `grim` can still capture the window just fine. This is because you may still want to take a screenshot of such windows. However, some screenshot tools display a fullscreen overlay with a frozen image of the screen, and then capture that. This overlay is *not* blocked out in the same way, and may leak the window contents to an active screencast. When `block-out-from = "screen-capture";`, this window is blocked out from `wlr-screencopy` and thus will never leak in such a case, but of course it will always be blocked out from screenshots and (sometimes) the physical screen.

1. The built in `screenshot` action, implemented in niri itself. This tool works similarly to those based on `wlr-screencopy`, but being a part of the compositor gets superpowers regarding secrecy of window contents. Its frozen overlay will never leak window contents to an active screencast, because information of blocked windows and can be distinguished for the physical output and screencasts. `block-out-from` does not affect the built in screenshot tool at all, and you can always take a screenshot of any window.

| `block-out-from` | can `ScreenCast`? | can `screencopy`? | can `screenshot`? |
| --- | :---: | :---: | :---: |
| `null` | yes | yes | yes |
| `"screencast"` | no | yes | yes |
| `"screen-capture"` | no | no | yes |

> [!caution]
> **Streamers: Do not accidentally leak window contents via screenshots.**
>
> For windows where `block-out-from = "screencast";`, contents of a window may still be visible in a screencast, if the window is indirectly displayed by a tool using `wlr-screencopy`.
>
> If you are a streamer, either:
> - make sure not to use `wlr-screencopy` tools that display a preview during your stream, or
> - **set `block-out-from = "screen-capture";` to ensure that the window is never visible in a screencast.**

> [!caution]
> **Do not let malicious `wlr-screencopy` clients capture your top secret windows.**
>
> (and don't let malicious software run on your system in the first place, you silly goose)
>
> For windows where `block-out-from = "screencast";`, contents of a window will still be visible to any application using `wlr-screencopy`, even if you did not consent to this application capturing your screen.
>
> Note that sandboxed clients restricted via security context (i.e. Flatpaks) do not have access to `wlr-screencopy` at all, and are not a concern.
>
> **If a window's contents are so secret that they must never be captured by any (non-sandboxed) application, set `block-out-from = "screen-capture";`.**

Essentially, use `block-out-from = "screen-capture";` if you want to be sure that the window is never visible to any external tool no matter what; or use `block-out-from = "screencast";` if you want to be able to capture screenshots of the window without its contents normally being visible in a screencast. (at the risk of some tools still leaking the window contents, see above)


<!-- sorting key: programs.niri.settings.o.window-rules.e.border -->
## `programs.niri.settings.window-rules.*.border`


See [`layout.border`](#programsnirisettingslayoutborder).


<!-- sorting key: programs.niri.settings.o.window-rules.e.border.a.enable -->
## `programs.niri.settings.window-rules.*.border.enable`
- type: `null or boolean`
- default: `null`

Whether to enable the border.


<!-- sorting key: programs.niri.settings.o.window-rules.e.border.a.width -->
## `programs.niri.settings.window-rules.*.border.width`
- type: `null or floating point number or signed integer`
- default: `null`

The width of the border drawn around each matched window.


<!-- sorting key: programs.niri.settings.o.window-rules.e.border.b.active -->
## `programs.niri.settings.window-rules.*.border.active`
- type: `null or `[`<decoration>`](#decoration)
- default: `null`

The color of the border for the window that has keyboard focus.


<!-- sorting key: programs.niri.settings.o.window-rules.e.border.b.inactive -->
## `programs.niri.settings.window-rules.*.border.inactive`
- type: `null or `[`<decoration>`](#decoration)
- default: `null`

The color of the border for windows that do not have keyboard focus.


<!-- sorting key: programs.niri.settings.o.window-rules.e.clip-to-geometry -->
## `programs.niri.settings.window-rules.*.clip-to-geometry`
- type: `null or boolean`
- default: `null`

Whether to clip the window to its visual geometry, i.e. whether the corner radius should be applied to the window surface itself or just the decorations.


<!-- sorting key: programs.niri.settings.o.window-rules.e.draw-border-with-background -->
## `programs.niri.settings.window-rules.*.draw-border-with-background`
- type: `null or boolean`
- default: `null`

Whether to draw the focus ring and border with a background.

Normally, for windows with server-side decorations, niri will draw an actual border around them, because it knows they will be rectangular.

Because client-side decorations can take on arbitrary shapes, most notably including rounded corners, niri cannot really know the "correct" place to put a border, so for such windows it will draw a solid rectangle behind them instead.

For most windows, this looks okay. At worst, you have some uneven/jagged borders, instead of a gaping hole in the region outside of the corner radius of the window but inside its bounds.

If you wish to make windows sucha s your terminal transparent, and they use CSD, this is very undesirable. Instead of showing your wallpaper, you'll get a solid rectangle.

You can set this option per window to override niri's default behaviour, and instruct it to omit the border background for CSD windows. You can also explicitly enable it for SSD windows.


<!-- sorting key: programs.niri.settings.o.window-rules.e.focus-ring -->
## `programs.niri.settings.window-rules.*.focus-ring`


See [`layout.focus-ring`](#programsnirisettingslayoutfocus-ring).


<!-- sorting key: programs.niri.settings.o.window-rules.e.focus-ring.a.enable -->
## `programs.niri.settings.window-rules.*.focus-ring.enable`
- type: `null or boolean`
- default: `null`

Whether to enable the focus ring.


<!-- sorting key: programs.niri.settings.o.window-rules.e.focus-ring.a.width -->
## `programs.niri.settings.window-rules.*.focus-ring.width`
- type: `null or floating point number or signed integer`
- default: `null`

The width of the focus ring drawn around each matched window with focus.


<!-- sorting key: programs.niri.settings.o.window-rules.e.focus-ring.b.active -->
## `programs.niri.settings.window-rules.*.focus-ring.active`
- type: `null or `[`<decoration>`](#decoration)
- default: `null`

The color of the focus ring for the window that has keyboard focus.


<!-- sorting key: programs.niri.settings.o.window-rules.e.focus-ring.b.inactive -->
## `programs.niri.settings.window-rules.*.focus-ring.inactive`
- type: `null or `[`<decoration>`](#decoration)
- default: `null`

The color of the focus ring for windows that do not have keyboard focus.


<!-- sorting key: programs.niri.settings.o.window-rules.e.geometry-corner-radius -->
## `programs.niri.settings.window-rules.*.geometry-corner-radius`
- type: `null or (submodule)`
- default: `null`

The corner radii of the window decorations (border, focus ring, and shadow) in logical pixels.

By default, the actual window surface will be unaffected by this.

Set [`window-rules.*.clip-to-geometry`](#programsnirisettingswindow-rulesclip-to-geometry) to true to clip the window to its visual geometry, i.e. apply the corner radius to the window surface itself.


<!-- sorting key: programs.niri.settings.o.window-rules.e.geometry-corner-radius.bottom-left -->
## `programs.niri.settings.window-rules.*.geometry-corner-radius.bottom-left`
- type: `floating point number`


<!-- sorting key: programs.niri.settings.o.window-rules.e.geometry-corner-radius.bottom-right -->
## `programs.niri.settings.window-rules.*.geometry-corner-radius.bottom-right`
- type: `floating point number`


<!-- sorting key: programs.niri.settings.o.window-rules.e.geometry-corner-radius.top-left -->
## `programs.niri.settings.window-rules.*.geometry-corner-radius.top-left`
- type: `floating point number`


<!-- sorting key: programs.niri.settings.o.window-rules.e.geometry-corner-radius.top-right -->
## `programs.niri.settings.window-rules.*.geometry-corner-radius.top-right`
- type: `floating point number`


<!-- sorting key: programs.niri.settings.o.window-rules.e.opacity -->
## `programs.niri.settings.window-rules.*.opacity`
- type: `null or floating point number`
- default: `null`

The opacity of the window, ranging from 0 to 1.

If the final value of this field is null, niri will fall back to a value of 1.

Note that this is applied in addition to the opacity set by the client. Setting this to a semitransparent value on a window that is already semitransparent will make it even more transparent.


<!-- sorting key: programs.niri.settings.o.window-rules.e.shadow -->
<!-- programs.niri.settings.window-rules.*.shadow -->

<!-- sorting key: programs.niri.settings.o.window-rules.e.shadow.color -->
## `programs.niri.settings.window-rules.*.shadow.color`
- type: `null or string`
- default: `null`


<!-- sorting key: programs.niri.settings.o.window-rules.e.shadow.draw-behind-window -->
## `programs.niri.settings.window-rules.*.shadow.draw-behind-window`
- type: `null or boolean`
- default: `null`


<!-- sorting key: programs.niri.settings.o.window-rules.e.shadow.enable -->
## `programs.niri.settings.window-rules.*.shadow.enable`
- type: `null or boolean`
- default: `null`


<!-- sorting key: programs.niri.settings.o.window-rules.e.shadow.inactive-color -->
## `programs.niri.settings.window-rules.*.shadow.inactive-color`
- type: `null or string`
- default: `null`


<!-- sorting key: programs.niri.settings.o.window-rules.e.shadow.offset -->
## `programs.niri.settings.window-rules.*.shadow.offset`
- type: `null or (submodule)`
- default: `null`

The offset of the shadow from the window, measured in logical pixels.

This behaves like a [CSS box-shadow offset](https://developer.mozilla.org/en-US/docs/Web/CSS/box-shadow#syntax)


<!-- sorting key: programs.niri.settings.o.window-rules.e.shadow.offset.x -->
## `programs.niri.settings.window-rules.*.shadow.offset.x`
- type: `floating point number or signed integer`


<!-- sorting key: programs.niri.settings.o.window-rules.e.shadow.offset.y -->
## `programs.niri.settings.window-rules.*.shadow.offset.y`
- type: `floating point number or signed integer`


<!-- sorting key: programs.niri.settings.o.window-rules.e.shadow.softness -->
## `programs.niri.settings.window-rules.*.shadow.softness`
- type: `null or floating point number or signed integer`
- default: `null`

The softness/size of the shadow, measured in logical pixels.

This behaves like a [CSS box-shadow blur-radius](https://developer.mozilla.org/en-US/docs/Web/CSS/box-shadow#syntax)


<!-- sorting key: programs.niri.settings.o.window-rules.e.shadow.spread -->
## `programs.niri.settings.window-rules.*.shadow.spread`
- type: `null or floating point number or signed integer`
- default: `null`

The spread of the shadow, measured in logical pixels.

This behaves like a [CSS box-shadow spread radius](https://developer.mozilla.org/en-US/docs/Web/CSS/box-shadow#syntax)


<!-- sorting key: programs.niri.settings.o.window-rules.e.tab-indicator.active -->
## `programs.niri.settings.window-rules.*.tab-indicator.active`
- type: `null or `[`<decoration>`](#decoration)
- default: `null`

See [`layout.tab-indicator.active`](#programsnirisettingslayouttab-indicatoractive).


<!-- sorting key: programs.niri.settings.o.window-rules.e.tab-indicator.inactive -->
## `programs.niri.settings.window-rules.*.tab-indicator.inactive`
- type: `null or `[`<decoration>`](#decoration)
- default: `null`

See [`layout.tab-indicator.inactive`](#programsnirisettingslayouttab-indicatorinactive).


<!-- sorting key: programs.niri.settings.o.window-rules.f.max-height -->
## `programs.niri.settings.window-rules.*.max-height`
- type: `null or signed integer`
- default: `null`

Sets the maximum height (in logical pixels) that niri will ever ask this window for.

Keep in mind that the window itself always has a final say in its size, and may not respect the maximum height set by this option.


Also, note that the maximum height is not taken into account when automatically sizing columns. That is, when a column is created normally, windows in it will be "automatically sized" to fill the vertical space. This algorithm will respect a minimum height, and not make windows any smaller than that, but the max height is only taken into account if it is equal to the min height. In other words, it will only accept a "fixed height" or a "minimum height". In practice, most windows do not set a max size unless it is equal to their min size, so this is usually not a problem without window rules.

If you manually change the window heights, then max-height will be taken into account and restrict you from making it any taller, as you'd intuitively expect.


<!-- sorting key: programs.niri.settings.o.window-rules.f.max-width -->
## `programs.niri.settings.window-rules.*.max-width`
- type: `null or signed integer`
- default: `null`

Sets the maximum width (in logical pixels) that niri will ever ask this window for.

Keep in mind that the window itself always has a final say in its size, and may not respect the maximum width set by this option.


<!-- sorting key: programs.niri.settings.o.window-rules.f.min-height -->
## `programs.niri.settings.window-rules.*.min-height`
- type: `null or signed integer`
- default: `null`

Sets the minimum height (in logical pixels) that niri will ever ask this window for.

Keep in mind that the window itself always has a final say in its size, and may not respect the minimum height set by this option.


<!-- sorting key: programs.niri.settings.o.window-rules.f.min-width -->
## `programs.niri.settings.window-rules.*.min-width`
- type: `null or signed integer`
- default: `null`

Sets the minimum width (in logical pixels) that niri will ever ask this window for.

Keep in mind that the window itself always has a final say in its size, and may not respect the minimum width set by this option.


<!-- sorting key: programs.niri.settings.o.window-rules.g.baba-is-float -->
## `programs.niri.settings.window-rules.*.baba-is-float`
- type: `null or boolean`
- default: `null`

Makes your window FLOAT up and down, like in the game Baba Is You.

Made for April Fools 2025.


<!-- sorting key: programs.niri.settings.o.window-rules.g.default-floating-position -->
## `programs.niri.settings.window-rules.*.default-floating-position`
- type: `null or (submodule)`
- default: `null`

The default position for this window when it enters the floating layout.

If a window is created as floating, it will be placed at this position.

If a window is created as tiling, then later made floating, it will be placed at this position.

If a window has already been placed as floating through one of the above methods, and moved back to the tiling layout, then this option has no effect the next time it enters the floating layout. It will be placed at the same position it was last time.

The `x` and `y` fields are the distances from the edge of the screen to the edge of the window, in logical pixels. The `relative-to` field determines which two edges of the window and screen that these distances are measured from.


<!-- sorting key: programs.niri.settings.o.window-rules.g.default-floating-position.relative-to -->
## `programs.niri.settings.window-rules.*.default-floating-position.relative-to`
- type: `one of "top-left", "top-right", "bottom-left", "bottom-right", "top", "bottom", "left", "right"`


<!-- sorting key: programs.niri.settings.o.window-rules.g.default-floating-position.x -->
## `programs.niri.settings.window-rules.*.default-floating-position.x`
- type: `floating point number or signed integer`


<!-- sorting key: programs.niri.settings.o.window-rules.g.default-floating-position.y -->
## `programs.niri.settings.window-rules.*.default-floating-position.y`
- type: `floating point number or signed integer`


<!-- sorting key: programs.niri.settings.o.window-rules.h.variable-refresh-rate -->
## `programs.niri.settings.window-rules.*.variable-refresh-rate`
- type: `null or boolean`
- default: `null`

Takes effect only when the window is on an output with [`outputs.*.variable-refresh-rate`](#programsnirisettingsoutputsvariable-refresh-rate) set to `"on-demand"`. If the final value of this field is true, then the output will enable variable refresh rate when this window is present on it.


<!-- sorting key: programs.niri.settings.o.window-rules.i.scroll-factor -->
## `programs.niri.settings.window-rules.*.scroll-factor`
- type: `null or floating point number or signed integer`
- default: `null`


<!-- sorting key: programs.niri.settings.o.window-rules.j.tiled-state -->
## `programs.niri.settings.window-rules.*.tiled-state`
- type: `null or boolean`
- default: `null`


<!-- sorting key: programs.niri.settings.p.layer-rules -->
## `programs.niri.settings.layer-rules`
- type: `list of layer rule`

Layer rules.

A layer rule will match based on [`layer-rules.*.matches`](#programsnirisettingslayer-rulesmatches) and [`layer-rules.*.excludes`](#programsnirisettingslayer-rulesexcludes). Both of these are lists of "match rules".

A given match rule can match based on one of several fields. For a given match rule to "match" a layer surface, it must match on all fields.

- The `namespace` field, when non-null, is a regular expression. It will match a layer surface for which the client has set a namespace that matches the regular expression.


- The `at_startup` field, when non-null, will match a layer surface based on whether it was opened within the first 60 seconds of niri starting up.

- If a field is null, it will always match.

For a given layer rule to match a layer surface, the above logic is employed to determine whether any given match rule matches, and the interactions between the match rules decide whether the layer rule as a whole will match. For a given layer rule:

- A given layer surface is "considered" if any of the match rules in [`layer-rules.*.matches`](#programsnirisettingslayer-rulesmatches) successfully match this layer surface. If all of the match rules do not match this layer surface, then that layer surface will never match this layer rule.

- If [`layer-rules.*.matches`](#programsnirisettingslayer-rulesmatches) contains no match rules, it will match any layer surface and "consider" it for this layer rule.

- If a given layer surface is "considered" for this layer rule according to the above rules, the selection can be further refined with [`layer-rules.*.excludes`](#programsnirisettingslayer-rulesexcludes). If any of the match rules in `excludes` match this layer surface, it will be rejected and this layer rule will not match the given layer surface.

That is, a given layer rule will apply to a given layer surface if any of the entries in [`layer-rules.*.matches`](#programsnirisettingslayer-rulesmatches) match that layer surface (or there are none), AND none of the entries in [`layer-rules.*.excludes`](#programsnirisettingslayer-rulesexcludes) match that layer surface.

All fields of a layer rule can be set to null, which represents that the field shall have no effect on the layer surface (and in general, the client is allowed to choose the initial value).

To compute the final set of layer rules that apply to a given layer surface, each layer rule in this list is consdered in order.

At first, every field is set to null.

Then, for each applicable layer rule:

- If a given field is null on this layer rule, it has no effect. It does nothing and "inherits" the value from the previous rule.
- If the given field is not null, it will overwrite the value from any previous rule.

The "final value" of a field is simply its value at the end of this process. That is, the final value of a field is the one from the *last* layer rule that matches the given layer rule (not considering null entries, unless there are no non-null entries)

If the final value of a given field is null, then it usually means that the client gets to decide. For more information, see the documentation for each field.


<!-- sorting key: programs.niri.settings.p.layer-rules.a.matches -->
## `programs.niri.settings.layer-rules.*.matches`
- type: `list of match rule`

A list of rules to match layer surfaces.

If any of these rules match a layer surface (or there are none), that layer rule will be considered for this layer surface. It can still be rejected by [`layer-rules.*.excludes`](#programsnirisettingslayer-rulesexcludes)

If all of the rules do not match a layer surface, then this layer rule will not apply to that layer surface.


<!-- sorting key: programs.niri.settings.p.layer-rules.a.matches.a.namespace -->
## `programs.niri.settings.layer-rules.*.matches.*.namespace`
- type: `null or regular expression`
- default: `null`

A regular expression to match against the namespace of the layer surface.

All layer surfaces have a namespace set once at creation. When this rule is non-null, the regex must match the namespace of the layer surface for this rule to match.


<!-- sorting key: programs.niri.settings.p.layer-rules.a.matches.b.at-startup -->
## `programs.niri.settings.layer-rules.*.matches.*.at-startup`
- type: `null or boolean`
- default: `null`

When true, this rule will match layer surfaces opened within the first 60 seconds of niri starting up. When false, this rule will match layer surfaces opened *more than* 60 seconds after niri started up. This is useful for applying different rules to layer surfaces opened from [`spawn-at-startup`](#programsnirisettingsspawn-at-startup) versus those opened later.


<!-- sorting key: programs.niri.settings.p.layer-rules.b.excludes -->
## `programs.niri.settings.layer-rules.*.excludes`
- type: `list of match rule`

A list of rules to exclude layer surfaces.

If any of these rules match a layer surface, then this layer rule will not apply to that layer surface, even if it matches one of the rules in [`layer-rules.*.matches`](#programsnirisettingslayer-rulesmatches)

If none of these rules match a layer surface, then this layer rule will not be rejected. It will apply to that layer surface if and only if it matches one of the rules in [`layer-rules.*.matches`](#programsnirisettingslayer-rulesmatches)


<!-- sorting key: programs.niri.settings.p.layer-rules.b.excludes.a.namespace -->
## `programs.niri.settings.layer-rules.*.excludes.*.namespace`
- type: `null or regular expression`
- default: `null`

A regular expression to match against the namespace of the layer surface.

All layer surfaces have a namespace set once at creation. When this rule is non-null, the regex must match the namespace of the layer surface for this rule to match.


<!-- sorting key: programs.niri.settings.p.layer-rules.b.excludes.b.at-startup -->
## `programs.niri.settings.layer-rules.*.excludes.*.at-startup`
- type: `null or boolean`
- default: `null`

When true, this rule will match layer surfaces opened within the first 60 seconds of niri starting up. When false, this rule will match layer surfaces opened *more than* 60 seconds after niri started up. This is useful for applying different rules to layer surfaces opened from [`spawn-at-startup`](#programsnirisettingsspawn-at-startup) versus those opened later.


<!-- sorting key: programs.niri.settings.p.layer-rules.c.block-out-from -->
## `programs.niri.settings.layer-rules.*.block-out-from`
- type: `null or one of "screencast", "screen-capture"`
- default: `null`

Whether to block out this window from screen captures. When the final value of this field is null, it is not blocked out from screen captures.

This is useful to protect sensitive information, like the contents of password managers or private chats. It is very important to understand the implications of this option, as described below, **especially if you are a streamer or content creator**.

Some of this may be obvious, but in general, these invariants *should* hold true:
- a window is never meant to be blocked out from the actual physical screen (otherwise you wouldn't be able to see it at all)
- a `block-out-from` window *is* meant to be always blocked out from screencasts (as they are often used for livestreaming etc)
- a `block-out-from` window is *not* supposed to be blocked from screenshots (because usually these are not broadcasted live, and you generally know what you're taking a screenshot of)

There are three methods of screencapture in niri:

1. The `org.freedesktop.portal.ScreenCast` interface, which is used by tools like OBS primarily to capture video. When `block-out-from = "screencast";` or `block-out-from = "screen-capture";`, this window is blocked out from the screencast portal, and will not be visible to screencasting software making use of the screencast portal.

1. The `wlr-screencopy` protocol, which is used by tools like `grim` primarily to capture screenshots. When `block-out-from = "screencast";`, this protocol is not affected and tools like `grim` can still capture the window just fine. This is because you may still want to take a screenshot of such windows. However, some screenshot tools display a fullscreen overlay with a frozen image of the screen, and then capture that. This overlay is *not* blocked out in the same way, and may leak the window contents to an active screencast. When `block-out-from = "screen-capture";`, this window is blocked out from `wlr-screencopy` and thus will never leak in such a case, but of course it will always be blocked out from screenshots and (sometimes) the physical screen.

1. The built in `screenshot` action, implemented in niri itself. This tool works similarly to those based on `wlr-screencopy`, but being a part of the compositor gets superpowers regarding secrecy of window contents. Its frozen overlay will never leak window contents to an active screencast, because information of blocked windows and can be distinguished for the physical output and screencasts. `block-out-from` does not affect the built in screenshot tool at all, and you can always take a screenshot of any window.

| `block-out-from` | can `ScreenCast`? | can `screencopy`? | can `screenshot`? |
| --- | :---: | :---: | :---: |
| `null` | yes | yes | yes |
| `"screencast"` | no | yes | yes |
| `"screen-capture"` | no | no | yes |

> [!caution]
> **Streamers: Do not accidentally leak window contents via screenshots.**
>
> For windows where `block-out-from = "screencast";`, contents of a window may still be visible in a screencast, if the window is indirectly displayed by a tool using `wlr-screencopy`.
>
> If you are a streamer, either:
> - make sure not to use `wlr-screencopy` tools that display a preview during your stream, or
> - **set `block-out-from = "screen-capture";` to ensure that the window is never visible in a screencast.**

> [!caution]
> **Do not let malicious `wlr-screencopy` clients capture your top secret windows.**
>
> (and don't let malicious software run on your system in the first place, you silly goose)
>
> For windows where `block-out-from = "screencast";`, contents of a window will still be visible to any application using `wlr-screencopy`, even if you did not consent to this application capturing your screen.
>
> Note that sandboxed clients restricted via security context (i.e. Flatpaks) do not have access to `wlr-screencopy` at all, and are not a concern.
>
> **If a window's contents are so secret that they must never be captured by any (non-sandboxed) application, set `block-out-from = "screen-capture";`.**

Essentially, use `block-out-from = "screen-capture";` if you want to be sure that the window is never visible to any external tool no matter what; or use `block-out-from = "screencast";` if you want to be able to capture screenshots of the window without its contents normally being visible in a screencast. (at the risk of some tools still leaking the window contents, see above)


<!-- sorting key: programs.niri.settings.p.layer-rules.c.opacity -->
## `programs.niri.settings.layer-rules.*.opacity`
- type: `null or floating point number`
- default: `null`

The opacity of the window, ranging from 0 to 1.

If the final value of this field is null, niri will fall back to a value of 1.

Note that this is applied in addition to the opacity set by the client. Setting this to a semitransparent value on a window that is already semitransparent will make it even more transparent.


<!-- sorting key: programs.niri.settings.p.layer-rules.d.geometry-corner-radius -->
## `programs.niri.settings.layer-rules.*.geometry-corner-radius`
- type: `null or (submodule)`
- default: `null`

The corner radii of the surface decorations (shadow) in logical pixels.


<!-- sorting key: programs.niri.settings.p.layer-rules.d.geometry-corner-radius.bottom-left -->
## `programs.niri.settings.layer-rules.*.geometry-corner-radius.bottom-left`
- type: `floating point number`


<!-- sorting key: programs.niri.settings.p.layer-rules.d.geometry-corner-radius.bottom-right -->
## `programs.niri.settings.layer-rules.*.geometry-corner-radius.bottom-right`
- type: `floating point number`


<!-- sorting key: programs.niri.settings.p.layer-rules.d.geometry-corner-radius.top-left -->
## `programs.niri.settings.layer-rules.*.geometry-corner-radius.top-left`
- type: `floating point number`


<!-- sorting key: programs.niri.settings.p.layer-rules.d.geometry-corner-radius.top-right -->
## `programs.niri.settings.layer-rules.*.geometry-corner-radius.top-right`
- type: `floating point number`


<!-- sorting key: programs.niri.settings.p.layer-rules.d.shadow -->
<!-- programs.niri.settings.layer-rules.*.shadow -->

<!-- sorting key: programs.niri.settings.p.layer-rules.d.shadow.color -->
## `programs.niri.settings.layer-rules.*.shadow.color`
- type: `null or string`
- default: `null`


<!-- sorting key: programs.niri.settings.p.layer-rules.d.shadow.draw-behind-window -->
## `programs.niri.settings.layer-rules.*.shadow.draw-behind-window`
- type: `null or boolean`
- default: `null`


<!-- sorting key: programs.niri.settings.p.layer-rules.d.shadow.enable -->
## `programs.niri.settings.layer-rules.*.shadow.enable`
- type: `null or boolean`
- default: `null`


<!-- sorting key: programs.niri.settings.p.layer-rules.d.shadow.inactive-color -->
## `programs.niri.settings.layer-rules.*.shadow.inactive-color`
- type: `null or string`
- default: `null`


<!-- sorting key: programs.niri.settings.p.layer-rules.d.shadow.offset -->
## `programs.niri.settings.layer-rules.*.shadow.offset`
- type: `null or (submodule)`
- default: `null`

The offset of the shadow from the window, measured in logical pixels.

This behaves like a [CSS box-shadow offset](https://developer.mozilla.org/en-US/docs/Web/CSS/box-shadow#syntax)


<!-- sorting key: programs.niri.settings.p.layer-rules.d.shadow.offset.x -->
## `programs.niri.settings.layer-rules.*.shadow.offset.x`
- type: `floating point number or signed integer`


<!-- sorting key: programs.niri.settings.p.layer-rules.d.shadow.offset.y -->
## `programs.niri.settings.layer-rules.*.shadow.offset.y`
- type: `floating point number or signed integer`


<!-- sorting key: programs.niri.settings.p.layer-rules.d.shadow.softness -->
## `programs.niri.settings.layer-rules.*.shadow.softness`
- type: `null or floating point number or signed integer`
- default: `null`

The softness/size of the shadow, measured in logical pixels.

This behaves like a [CSS box-shadow blur-radius](https://developer.mozilla.org/en-US/docs/Web/CSS/box-shadow#syntax)


<!-- sorting key: programs.niri.settings.p.layer-rules.d.shadow.spread -->
## `programs.niri.settings.layer-rules.*.shadow.spread`
- type: `null or floating point number or signed integer`
- default: `null`

The spread of the shadow, measured in logical pixels.

This behaves like a [CSS box-shadow spread radius](https://developer.mozilla.org/en-US/docs/Web/CSS/box-shadow#syntax)


<!-- sorting key: programs.niri.settings.p.layer-rules.e.baba-is-float -->
## `programs.niri.settings.layer-rules.*.baba-is-float`
- type: `null or boolean`
- default: `null`

Make your layer surfaces FLOAT up and down.

This is a natural extension of the April Fools' 2025 feature.


<!-- sorting key: programs.niri.settings.p.layer-rules.e.place-within-backdrop -->
## `programs.niri.settings.layer-rules.*.place-within-backdrop`
- type: `null or boolean`
- default: `null`

Set to `true` to place the surface into the backdrop visible in the Overview and between workspaces.
This will only work for background layer surfaces that ignore exclusive zones (typical for wallpaper tools). Layers within the backdrop will ignore all input.


<!-- sorting key: programs.niri.settings.q.debug -->
## `programs.niri.settings.debug`
- type: `attribute set of kdl arguments`

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
