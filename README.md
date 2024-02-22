This flake provides a NixOS module with an option `programs.niri.enable`. You can import it into your system configuration and enable it to install niri.

It also provides a home-manager module with an option `programs.niri.config`, which not only manages your `config.kdl` declaratively, but also validates it at build-time. This ensures that your config's schema is always in sync with the installed version of niri.

You do not have to be on NixOS to use the home-manager module. If you installed home-manager through the NixOS module (rather than a standalone setup, as is necessary on non-NixOS Linux systems), the option to declaratively manage the config will be automatically imported.

Now with additional capabilities! See [Additional Notes](#additional-notes)

# Usage

First of all, add the flake to your inputs.

By default, the modules provided use the `niri` package in nixpkgs.

If you would like to use a specific version of niri, you may set the option `programs.niri.package`.

This flake also provides a `packages.${system}.niri`, which should be overridden with `pkgs` to modify the nixpkgs version used (important, to ensure it is compiled against the correct version of mesa).

At the moment, you can override the `niri-src` input to use unstable niri. I plan to implement binary caching, and then this input should hopefully be unnecessary/deprecated. For now, i will not document using unstable niri.

---

If you're on NixOS and don't need to configure niri declaratively, your flake.nix should look something like this:

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
      ];
    };
  }
}
```

---

If you use home-manager as NixOS module, then your flake.nix should rather look something like this:

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

---

If you're using a standalone setup of home-manager (both NixOS and non-NixOS), you should first install niri through some other means. For NixOS, see above. For non-NixOS, i would recommend non-nix-based installation of niri. If you really want to, there is `homeModules.niri` which manages the config and also provides an option to install niri, but it may be less feature complete than the NixOS module. The home-manager module cannot register sessions in your display manager.

> [!note]
> If you install niri through home-manager (rather than merely configuring it), make sure it is compiled against the same version of mesa that you have installed. If you don't, niri might not start properly.
> The following applies mainly if you want to run niri unstable. By default, niri is packaged in `nixpkgs` and you needn't worry about any of this if that's what you rely on.
> 
> - If you're on NixOS and installing through the NixOS module, you don't need to worry about this. It's automatically synced exactly.
> - If you're on NixOS and installing through home-manager as a NixOS module, make sure sure `home-manager.useGlobalPkgs = true;`, and this will be handled automatically.
> - If you're on NixOS and installing through home-manager as a standalone tool (not recommended!), this should be easy to ensure with no override if you update your home and system configurations' `nixpkgs` inputs at the same time (so they stay in sync).
> - In general, this can be accomplished by setting `programs.niri.package` to `packages.x86_64_linux.niri.override { pkgs = ...; }` with a `pkgs` containing the correct version of mesa (this can be used to specify all the native dependencies that niri will build against).
> - If you're not installing niri through my flake and only use it to configure, I cannot help you.

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

---

# Additional notes

The modules `niri.nixosModules.niri` and `niri.homeModules.niri` provide the following functionality in common:

- They both install niri, as well as its systemd units and the `niri-session` binary.
- They both install and enable `xdg-desktop-portal-gnome`
- They both enable the GNOME keyring.

The NixOS module provides the following additional functionality:

- The NixOS module will enable polkit, and run the KDE polkit agent.
- If you prefer a different polkit authentication agent, you can set `systemd.user.services.niri-flake-polkit.enable = false;`
- It enables various other features that Wayland compositors may need, such as `dconf`, `opengl` and default fonts. It also adds a pam entry for `swaylock`, which is normally done by the compositor's module on NixOS.

Some additional software you may want to install to get a full desktop experience:

- A notification daemon such as `mako`
- A bar such as `waybar`
- A launcher such as `fuzzel`

These will generally be installed through home-manager. No particular configuration is necessary for them to work with niri specifically, as they generally start on `graphical-session.target` which includes niri.

If using waybar, you'll want to set `programs.waybar.settings.mainBar.layer = "top";`, to ensure it is visible over applications running in niri. You'll also wanna set `programs.waybar.systemd.enable = true;` which i've found seems somewhat unreliable. Your mileage may vary.

For electron applications such as vscode, you will want to set the `NIXOS_OZONE_WL` environment variable. Several package in nixpkgs look for this variable, and pass some ozone flags in that case. Note that they will only run as wayland applications if you run niri through `niri-session`; the raw `niri` binary will not set the necessary environment variables. If you insist on not running `niri-session`, you can pass the usual ozone flags manually. `NIXOS_OZONE_WL` is not set by this module, because you may want to set it in different places depending on your needs. `environment.variables` should works fine, though.

---

The packages built by this flake should work on aarch64, but i have no aarch64 computer to test it on. Please report any issues with aarch64.

I also have no way to test cross-compilation, and given that i consider it an obscure usecase, i did not bother to keep trying to maintain it. Please send a pull request if you're interested in cross-compilation.

Feel free to contact me in the `#niri:matrix.org` channel or through GitHub issues if you have any questions or concerns.