# niri-flake

This is a flake intended to install the niri wayland compositor on NixOS.

To use this, include `inputs.niri.url = "github:sodiboo/niri-flake";` in your system's `flake.nix`.

You should probably(?) also override its inputs for version control. This needs more investigation and is untested.

Then, add `niri.nixosModules.default` as a module to your system. The only stable outputs are `packages.x86_64-linux.niri` and `nixosModules.default`.

And finally, make sure that `programs.niri.enable = true;` in your config.

This is somewhat work-in-progress. The actual flake works, but these instructions need to be expanded on.

Feel free to contact me in the `#niri:matrix.org` channel or through GitHub issues if you have any questions or concerns.
