This flake contains nix packages [niri](https://github.com/YaLTeR/niri), a scrollable-tiling Wayland compositor. You can try it right now: add the binary cache with `cachix use niri` and then `nix run github:sodiboo/niri-flake`. You can also try the latest commit to the `main` branch with `nix run github:sodiboo/niri-flake#niri-unstable`.

This flake also contains NixOS and home-manager modules to install all necessary components of a working Wayland environment, and they let you manage your `config.kdl` declaratively, validating it at build-time. This ensures that your config's schema is always in sync with the installed version of niri.

Feel free to contact me at [`@sodiboo:arcticfoxes.net`](https://matrix.to/#/@sodiboo:arcticfoxes.net) in the [`#niri:matrix.org`](https://matrix.to/#/#niri:matrix.org) channel or through GitHub issues if you have any questions or concerns.

# Outputs

- `niri.packages.x86_64-linux.niri-stable`: The latest release of niri.
- `niri.packages.x86_64-linux.niri-unstable`: The latest commit to the `main` branch of the niri repository. This may break at any time without warning, and is not recommended for most users.
- `niri.packages.aarch64-linux`: aarch64 is entirely untested. Do not expect it to work, but do report any issues you encounter.
- `niri.overlays.niri`: A nixpkgs overlay that provides the `niri-stable` and `niri-unstable` attributes.
- `niri.kdl`: A library to write kdl files with nix syntax.

It is recommended to use the overlay to access the packages from this flake, as it will ensure that it is built against the same version of nixpkgs as the rest of your system. This is necessary, because the mesa drivers must match exactly.

- `niri.nixosModules.niri`: [Installion on NixOS](#installation-on-nixos)
- `niri.homeModules.niri`: [Installation with home-manager](#installation-with-home-manager)
- `niri.homeModules.config`: [Configuration with home-manager](#configuration-with-home-manager)
- `niri.homeModules.stylix`: [Stylix](#stylix)

# Binary Cache

I have a binary cache for this flake's outputs. Currently, it only hosts builds with the `nixos-unstable` channel of nixpkgs. As far as i'm aware, no users exist that are using stable nixpkgs channel. If that's you, please tell me about it so i can cache builds for you.

> [!note]
> This binary cache is managed by me, sodiboo. By using it, you are trusting me to not serve you malicious software. Using a binary cache is entirely optional.
>
> If you do not wish to use my binary cache, but still want the convenience of one, you could set `programs.niri.package = pkgs.niri;`, which is provided by nixpkgs. This package will receive updates slower.

If you use NixOS, add the `niri.nixosModules.niri` module and don't enable niri yet. Rebuild your system once to enable the binary cache, *then* enable niri. You can set `niri-flake.cache.enable = false;` to prevent this from happening.

If you're not using the NixOS module, you can add the cache to your system by running `cachix use niri`. This works on any system with nix installed, not just NixOS.

# Installation on NixOS

If you're on NixOS and don't need to configure niri declaratively, your flake.nix should look something like the following.

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    niri.url = "github:sodiboo/niri-flake";
  };

  outputs = { self, nixpkgs, niri, ... }: {
    nixosConfigurations.my-system = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        niri.nixosModules.niri
        {
          programs.niri.enable = true;
        }
        { # If you wish to use the unstable version of niri, you can set it like so:
          nixpkgs.overlays = [ niri.overlays.niri ];
          programs.niri.package = pkgs.niri-unstable;
        }
      ];
    };
  }
}
```

If you use home-manager as NixOS module, then your flake.nix could rather look something like this. The NixOS module will automatically import the home-manager config module if it detects that home-manager is installed as a NixOS module.

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    
    niri.url = "github:sodiboo/niri-flake";
  };

  outputs = { self, nixpkgs, home-manager, niri, ... }: {
    nixosConfigurations.my-system = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        home-manager.nixosModules.home-manager
        niri.nixosModules.niri
        {
          programs.niri.enable = true;
        }
        { # If you wish to use the unstable version of niri, you can set it like so:
          nixpkgs.overlays = [ niri.overlays.niri ];
          programs.niri.package = pkgs.niri-unstable;
        }
        {
          home-manager.users.my-user = {
            # For more info on available configuration options, see "Configuration with home-manager"
            programs.niri.settings = {
              outputs."eDP-1".scale = 2.0;
            };
          };
        }
      ];
    };
  }
}
```

# Installation with home-manager

You can install niri via home-manager using the `niri.homeModules.niri` output. For now, it's less complete than the "real" module, but it works mostly fine.

# Configuration with home-manager

`programs.niri.settings` is the preferred way to configure niri. This is provided by `niri.homeModules.config`, which is automatically imported when using home-manager as a NixOS module. (TODO: document the available options)
Doing it this way, your flake.nix will end up looking something like this:

```nix
{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    niri.url = "github:sodiboo/niri-flake";
  };

  outputs = { self, nixpkgs, home-manager, niri, ... }: let
    system = "x86_64-linux";
    pkgs = nixpkgs.legacyPackages.${system};
  in {
    homeConfigurations.my-user = home-manager.lib.homeManagerConfiguration {
      inherit pkgs;
      modules = [
        niri.homeModules.config
        {
          programs.niri.settings = {
            outputs."eDP-1".scale = 2.0;
          };
        }
      ];
    };
  };
}
```

If for whatever reason you want or need to override this, you can set `programs.niri.config`.
You should give this option structured output from the `niri.kdl` library.

```nix
{
  inputs = { /* ... */ };
  outputs = { niri, ...}: {
    homeModules.example-kdl-config = {
      programs.niri.config = with niri.kdl; [
        (node "output" "eDP-1" [
          (leaf "scale" 2.0)
        ])
      ];
    };
  };
}
```

But you can also pass it a string:

```nix
{
  inputs = { /* ... */ };
  outputs = { niri, ...}: {
    homeModules.example-string-config = {
      programs.niri.config = ''
        output "eDP-1" {
          scale 2.0
        }
      '';
    };
  };
}
```

or set `programs.niri.config = null;` to prevent this module from generating a config file.

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

These will generally be installed through home-manager. No particular configuration is necessary for them to work with niri specifically, as they generally start on `graphical-session.target` which includes niri.

If using waybar, you'll want to set `programs.waybar.settings.mainBar.layer = "top";`, to ensure it is visible over applications running in niri. You'll also wanna set `programs.waybar.systemd.enable = true;` which i've found seems somewhat unreliable. Your mileage may vary.

For electron applications such as vscode, you will want to set the `NIXOS_OZONE_WL` environment variable. Several packages in nixpkgs look for this variable, and pass some ozone flags in that case. Note that they will only run as wayland applications if you run niri through `niri-session`; the raw `niri` binary will not set the necessary environment variables. If you insist on not running `niri-session`, you can pass the usual ozone flags manually. `NIXOS_OZONE_WL` is not set by this module, because you may want to set it in different places depending on your needs. `environment.variables` should works fine, though.

Visual Studio Code does not properly detect the correct keyring to use on my system. It works fine if you launch it with `code --password-store="gnome-libsecret"`. You persist this flag in `Preferences > Configure Runtime Arguments` (`argv.json`), by setting `"password-store": "gnome-libsecret"`.
