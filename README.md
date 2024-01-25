This flake provides a NixOS module with an option `programs.niri.enable`. You can import it into your system configuration and enable it to install niri.

It also provides a home-manager module with an option `programs.niri.config`, which not only manages your `config.kdl` declaratively, but also validates it at build-time. This ensures that your config's schema is always in sync with the installed version of niri.

You do not have to be on NixOS to use the home-manager module. If you installed home-manager through the NixOS module (rather than a standalone setup, as is necessary on non-NixOS Linux systems), the option to declaratively manage the config will be automatically imported.

# Usage

First of all, add the flake to your inputs and override the `niri-src` input.

> [!important]
> Nix will automatically pin the `niri-src` input to the latest commit at the time of updating `niri-flake`.
> 
> Updating your own flake does not affect this pin, as `niri-flake`'s lockfile is separate from your own.  
> This is undesirable. Niri currently has no stable releases, so you will generally want the latest commit.
> 
> As such, you should manually override it. This is causes the `niri-src` input to be tied to your lockfile,  
> and then you can update niri by running `nix flake update`.

---

If you're on NixOS and don't need to configure niri declaratively, your flake.nix should look something like this:

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    niri.url = "github:sodiboo/niri-flake";
    niri.inputs.niri-src.url = "github:YaLTeR/niri";
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
    niri.inputs.niri-src.url = "github:YaLTeR/niri";
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

If you're using a standalone setup of home-manager (both NixOS and non-NixOS), you should first install niri through some other means. For NixOS, see above. For non-NixOS, i would recommend non-nix-based installation of niri. If you really want to, there is `homeModules.niri` which manages the config and also provides an option to install niri, but does not register sessions properly.

Once you've installed niri, and you want to configure niri, your flake.nix will end up looking something like this:

```nix
{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    niri.url = "github:sodiboo/niri-flake";
    niri.inputs.niri-src.url = "github:YaLTeR/niri";
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

The packages built by this flake should work on aarch64, but i have no aarch64 computer to test it on. Please report any issues with aarch64.

I also have no way to test cross-compilation, and given that i consider it an obscure usecase, i did not bother to keep trying to maintain it. Please send a pull request if you're interested in cross-compilation.

Feel free to contact me in the `#niri:matrix.org` channel or through GitHub issues if you have any questions or concerns.