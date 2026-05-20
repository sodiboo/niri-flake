This flake contains nix packages for [niri](https://github.com/YaLTeR/niri), a scrollable-tiling Wayland compositor. You can try it right now: add the binary cache with `cachix use niri` and then `nix run github:sodiboo/niri-flake`. You can also try the latest commit to the `main` branch with `nix run github:sodiboo/niri-flake#niri-unstable`.

This flake also contains NixOS and home-manager modules to install all necessary components of a working Wayland environment, and to let you manage your configuration declaratively, validating it at build-time. This ensures that your config's schema is always in sync with the installed version of niri.

**The main location for documentation is [`docs.md`](./docs.md)**. The most important outputs are `overlays.niri` and `nixosModules.niri`. You may also use my configuration as a reference at [`github:sodiboo/system`](https://github.com/sodiboo/system/blob/main/personal/niri.mod.nix)

The rest of this README covers miscellaneous topics related to this flake or repo as a whole.

Feel free to contact me at [`@sodiboo:gaysex.cloud`](https://matrix.to/#/@sodiboo:gaysex.cloud) in the [`#niri:matrix.org`](https://matrix.to/#/#niri:matrix.org) channel or through GitHub issues if you have any questions or concerns.

# A note on the automated pull requests in this repository

This repository uses automated pull requests extensively in order to automatically update the lockfile. If you wish to view pull requests made by humans, you can filter for [`is:pr -label:automated`](https://github.com/sodiboo/niri-flake/pulls?q=is%3Apr+-label%3Aautomated).

This is done in order to keep the `niri-unstable` version up-to-date. Niri doesn't have an inherent "unstable" versioning scheme (like e.g. Rust or NixOS does) and that terminology is specific to this flake. It is just the latest commit to main. It's equivalent to `niri-git` on the AUR.

Previously, this was done by telling you to override the niri-src input with the latest version (which puts it in your lockfile), but doing it here has two main benefits:

1. I can run various hooks to automatically update documentation with, at the very least, the niri version, but also other generated items such as listing the available actions (parsed from source code and enumerated in `docs.md`).
2. I can perform checks on the updated lockfile to ensure that nothing breaks with new niri updates.

There are two less obvious benefits:

3. By requiring the build job to succeed, i can ensure that the latest niri versions are always in my binary cache before the pull request is merged. This means you won't need to build it locally.
4. By also automatically updating nixpkgs, i can run checks to ensure the modules keep working with the latest nixpkgs.

Currently, there is no `home-manager` input to this flake since i felt it was unnecessary for *just* checks, and therefore configurations involving home-manager are *not* automatically tested at this time.

# Binary Cache

I have a binary cache for this flake's outputs. `niri.cachix.org` hosts builds of `niri-stable` and `niri-unstable` for `nixos-unstable` and `nixos-25.05`. It only contains builds for `x86_64-linux` for the time being, mainly because GitHub Actions doesn't support other platforms. (and i do not wish to use qemu for this)

> [!note]
> This binary cache is managed by me, sodiboo. By using it, you are trusting me to not serve you malicious software. Using a binary cache is entirely optional.
>
> If you do not wish to use my binary cache, but still want the convenience of one, you could set `programs.niri.package = pkgs.niri;`, which is provided by nixpkgs. This package will receive updates slower.

If you use NixOS, add the `niri.nixosModules.niri` module and don't enable niri yet. Rebuild your system once to enable the binary cache, *then* enable niri. You can set `niri-flake.cache.enable = false;` to prevent this from happening.

If you're not using the NixOS module, you can add the cache to your system by running `cachix use niri`. This works on any system with nix installed, not just NixOS.

# Using `niri-unstable`

Both `niri.nixosModules.niri` and `niri.homeModules.niri` provide the option to use a custom version of niri. This is done by setting `programs.niri.package` to the desired derivation. If you want to use the unstable version of niri, you can set it like so:

```nix
{pkgs, ...}: {
  nixpkgs.overlays = [ inputs.niri.overlays.niri ];
  programs.niri.package = pkgs.niri-unstable;
}
```

You can also set the package to the one from nixpkgs (`pkgs.niri`), which will likely receive updates slower than the `niri-stable` provided here.

`niri.homeModules.config` also provides the option to set the package. This won't install niri by itself, but it does set the package version used for build-time validation.

# Configuration of niri

`programs.niri.settings` is the preferred way to configure niri. This is provided by `niri.homeModules.config`, which is automatically imported when using home-manager as a NixOS module. All options are documented in [`docs.md`](./docs.md#programsnirisettings).

```nix
{
  programs.niri.settings = {
    outputs."eDP-1".scale = 2.0;
  };
}
```

If for whatever reason you want or need to override this, you can set `programs.niri.config`.
You should give this option structured output from `niri.lib.kdl`.

```nix
{
  programs.niri.config = with inputs.niri.lib.kdl; [
    (node "output" "eDP-1" [
      (leaf "scale" 2.0)
    ])
  ];
}
```

But you can also pass it a string:

```nix
{
  programs.niri.config = ''
    output "eDP-1" {
      scale 2.0
    }
  '';
}
```

By default its value is derived from `programs.niri.settings`.

You can also combine option-based configuration with manual one by
setting `programs.niri.extraConfig`.  It has the same type as
`programs.niri.config` and defaults to `null`.

If both `programs.niri.config` and `programs.niri.extraConfig` are
`null`, this module will not generate a config file at all.

For debugging (primarily development of this flake i guess), there is also `programs.niri.finalConfig` which is always a string (or null) and represents the final rendered config file that will end up in your config directory.

> [!note]
> `programs.niri.settings` is not guaranteed to be compatible with niri versions other than the two provided by this flake. \
> In particular, this means that i do not guarantee compatibility with the one from nixpkgs at all times (i.e. when nixpkgs is lagging behind due to build failures or other reasons). \
> In practice, you will not have an issue with this unless you are running old versions of niri that are 2 or more releases behind. I will try my best not to break compatibility with nixpkgs.
>
> This does not apply to `programs.niri.config` and `programs.niri.extraConfig` as those are inherently version-agnostic.
>
> The final config is always validated at build time.

# Stylix

A module is provided to integrate with Stylix. To use this, the main prerequisite is that you don't ever set `programs.niri.config`; this will override everything from `programs.niri.settings`, which is where the stylix module places config.

If you've installed home-manager and stylix as a NixOS module, then this will be automatically imported. Else, you'll have to import `niri.homeModules.stylix` yourself.

The stylix module provides the option to disable it: `stylix.targets.niri.enable = false;`. Note that it is already disabled by default if you have `stylix.autoEnable` set to false.

When enabled, the stylix module will set the active/inactive border colors, and set `layout.border` to be on by default. It also sets the xcursor theme and size.

# Additional notes

When installing niri using the modules provided by this flake:

- The niri package will be installed, including its systemd units and the `niri-session` binary.
- `xdg-desktop-portal-gnome` will be installed, as it is necessary for screencasting.
- The GNOME keyring will be enabled. You probably want a keyring installed.

Specifically the NixOS module provides the following additional functionality:

- It will enable polkit, and run the KDE polkit agent.
- If you prefer a different polkit authentication agent, you can set `systemd.user.services.niri-flake-polkit.enable = false;`
- It enables various other features that Wayland compositors may need, such as `dconf`, `opengl` and default fonts. It also adds a pam entry for `swaylock`, which is necessary if you wish to use `swaylock`.

Some additional software you may want to install to get a full desktop experience:

- A notification daemon such as `mako`
- A bar such as `waybar`
- A launcher such as `fuzzel`

These will usually be installed through home-manager. No particular configuration is necessary for them to work with niri specifically, as they generally start on `graphical-session.target` which includes niri.

If using waybar, you'll want to set `programs.waybar.settings.mainBar.layer = "top";`, to ensure it is visible over applications running in niri. You'll also wanna set `programs.waybar.systemd.enable = true;` which i've found seems to exceed the default restart limit of 5, so you may want to run `systemctl --user reset-failed waybar.service` in `spawn-at-startup` to get it to start.

For electron applications such as vscode, you will want to set `programs.niri.settings.environment."NIXOS_OZONE_WL" = "1"`. Several packages in nixpkgs look for this variable, and pass some ozone flags in that case. Note that you must use `niri-session` to start niri for this to have any effect, because running just `niri` will not set the neccecary environment variables.

Visual Studio Code does not properly detect the correct keyring to use on my system. It works fine if you launch it with `code --password-store="gnome-libsecret"`. You persist this flag in `Preferences > Configure Runtime Arguments` (`argv.json`), by setting `"password-store": "gnome-libsecret"`.
