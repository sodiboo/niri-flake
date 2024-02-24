This flake provides packages and modules for [niri](https://github.com/YaLTeR/niri), a scrollable-tiling Wayland compositor.

Mainly, it installs all necessary components of a working Wayland environment, and also lets you manage your niri `config.kdl` declaratively, validating it at build-time. This ensures that your config's schema is always in sync with the installed version of niri.

Feel free to contact me at [`@sodiboo:arcticfoxes.net`](https://matrix.to/#/@sodiboo:arcticfoxes.net) in the [`#niri:matrix.org`](https://matrix.to/#/#niri:matrix.org) channel or through GitHub issues if you have any questions or concerns.

# Outputs

Packages:

- `niri.packages.x86_64-linux.niri-stable`: The latest release of niri.
- `niri.packages.x86_64-linux.niri-unstable`: The latest commit to the `main` branch of the niri repository. This may break at any time without warning, and is not recommended for most users.
- `niri.packages.aarch64-linux`: aarch64 is entirely untested. Do not expect it to work, but do report any issues you encounter.
- `niri.overlays.niri`: A nixpkgs overlay that provides the `niri-stable` and `niri-unstable` attributes.

It is recommended to use the overlay to access the packages from this flake, as it will ensure that it is built against the same version of nixpkgs as the rest of your system. This is necessary, because the mesa drivers must match exactly.

Modules:

- `niri.nixosModules.niri`: [Installing on NixOS](#installing-on-nixos)
- `niri.homeModules.config`: [Usage with home-manager](#usage-with-home-manager)
- `niri.homeModules.niri`: [Usage with home-manager](#usage-with-home-manager)

# Binary cache

I have a binary cache for this flake's outputs. Currently, it only hosts builds with the `nixos-unstable` channel of nixpkgs.

> [!note]
> This binary cache is managed by me, sodiboo. By using it, you are trusting me to not serve you malicious software. Using a binary cache is entirely optional.
>
> If you do not wish to use my binary cache, but still want the convenience of one, you could set `programs.niri.package = pkgs.niri;`, which is provided by nixpkgs. This package will receive updates slower.

If you're using something close to the default configuration layout of NixOS, or you don't run NixOS at all:
- Install cachix (i.e. add `pkgs.cachix` to `environment.systemPackages` or `home.packages`)
- Run `cachix use niri`
- Follow the instructions to add the cache to your system. Depending on your system setup, you may not need to do anything.

If you run a more exotic nix configuration, or prefer not to install `cachix`, you can manually add it to your system configuration:

```nix
{
  nix.settings.substituters = [ "https://niri.cachix.org" ];
  nix.settings.trusted-public-keys = [ "niri.cachix.org-1:Wv0OmO7PsuocRKzfDoJ3mulSl7Z6oezYhGhR+3W2964=" ];
}
```

And of course, if you're setting it in your NixOS configuration, run `nixos-rebuild switch` to apply the changes before you continue with the rest of the instructions.

# Installing on NixOS

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

If you use home-manager as NixOS module, then your flake.nix could rather look something like this. The NixOS module will automatically import the home-manager module if it detects that home-manager is installed as a NixOS module.

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
            programs.niri.config = ''
              output "eDP-1" {
                scale 2.0
              }
            '';
          };
        }
      ];
    };
  }
}
```

# Usage with home-manager

If you're using a standalone installation of home-manager (even on non-NixOS), you should first install niri through some other means. For NixOS, see above.

Once you've installed niri, and you want to configure niri, your flake.nix will end up looking something like this:

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
          programs.niri.config = ''
            output "eDP-1" {
              scale 2.0
            }
          '';
        }
      ];
    };
  };
}
```

You can also install niri using home-manager with `niri.homeModules.niri` output. It does not receive the same love and care as the NixOS module, and as such i will *not* document using it here. If you're interested in using it, you can view the source code to see how it works.

One day, the home-manager module will be more feature complete.

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