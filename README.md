This flake provides a NixOS module with an option `programs.niri.enable`. You can import it into your system configuration and enable it to install niri.

> [!important]
> Nix will automatically pin the `niri-src` input to the latest commit at the time of updating `niri-flake`.
> 
> Updating your own flake does not affect this pin, as `niri-flake`'s lockfile is separate from your own.  
> This is undesirable. Niri currently has no stable releases, so you will generally want the latest commit.
> 
> As such, you should manually override it. This is causes the `niri-src` input to be tied to your lockfile,  
> and then you can update niri by running `nix flake update`.

Your flake.nix should look something like this:

```nix
{
  inputs = {
    niri.url = "github:sodiboo/niri-flake";
    niri.inputs.niri-src.url = "github:YaLTeR/niri";
  };

  outputs = { self, nixpkgs, niri, ... }: {
    nixosConfigurations.my-system = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        niri.nixosModules.default
        {
          programs.niri.enable = true;
        }
      ];
    };
  }
}
```

The following outputs are available:

- `outputs.nixosModules.default`
- `outputs.packages.x86_64-linux.default`
- `outputs.apps.x86_64-linux.default`

It may have other outputs, but they are not guaranteed to be stable if you are using it.  
Notably, `aarch64`-specific outputs are not stable as I do not have an `aarch64` machine to test them on. Please open an issue if you encounter any problems on `aarch64`.  
Of course, if you don't mind breaking changes, you can use them.

`inputs.niri-src` is also stable, and you are expected to be override it. It will never be renamed or removed.

---

A home-manager module will be available at some point in the future.

Feel free to contact me in the `#niri:matrix.org` channel or through GitHub issues if you have any questions or concerns.
