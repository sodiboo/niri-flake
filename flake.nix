{
  description = "A scrollable-tiling Wayland compositor.";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixpkgs-stable.url = "github:NixOS/nixpkgs/nixos-25.11";

    niri-stable.url = "github:YaLTeR/niri/v25.08";
    niri-unstable.url = "github:YaLTeR/niri";

    xwayland-satellite-stable.url = "github:Supreeeme/xwayland-satellite/v0.7";
    xwayland-satellite-unstable.url = "github:Supreeeme/xwayland-satellite";

    # they do all have flakes, but we specifically want just the Rust sources and no flakes.
    niri-stable.flake = false;
    niri-unstable.flake = false;
    xwayland-satellite-stable.flake = false;
    xwayland-satellite-unstable.flake = false;
  };

  outputs =
    inputs@{
      self,
      nixpkgs,
      nixpkgs-stable,
      ...
    }:
    let
      call = nixpkgs.lib.flip import {
        inherit
          self
          inputs
          kdl
          docs
          binds
          settings
          ;
        inherit (nixpkgs) lib;
      };
      kdl = call ./files/kdl.nix;
      binds = call ./files/parse-binds.nix;
      docs = call ./files/generate-docs.nix;
      html-docs = call ./files/generate-html-docs.nix;
      settings = call ./files/settings.nix;
      validateConfig = import ./files/validate-config.nix;
      packageSet = import ./files/package.nix {
        inherit inputs;
      };
      cachedPackages = import ./files/cached-packages.nix {
        inherit inputs;
        lib = nixpkgs.lib;
      };

      date = {
        year = builtins.substring 0 4;
        month = builtins.substring 4 2;
        day = builtins.substring 6 2;
        hour = builtins.substring 8 2;
        minute = builtins.substring 10 2;
        second = builtins.substring 12 2;
      };

      fmt-date = raw: "${date.year raw}-${date.month raw}-${date.day raw}";
      fmt-time = raw: "${date.hour raw}:${date.minute raw}:${date.second raw}";

      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];

      forAllSystems = nixpkgs.lib.genAttrs systems;
    in
    {
      lib = {
        inherit kdl;
        internal = {
          inherit packageSet validateConfig;
          package-set = abort "niri-flake internals: `package-set.\${package} pkgs` is now `(make-package-set pkgs).\${package}`";
          docs-markdown = docs.make-docs (settings.fake-docs { inherit fmt-date fmt-time; });
          docs-html = html-docs.make-docs (settings.type-with html-docs.settings-fmt);
          settings-module = settings.module;
          memo-binds = nixpkgs.lib.pipe (binds "${inputs.niri-unstable}/niri-config/src/binds.rs") [
            (map (bind: "  \"${bind.name}\""))
            (builtins.concatStringsSep "\n")
            (memo'd: ''
              # This is a generated file.
              # It caches the output of `parse-binds.nix` for the latest niri-unstable.
              # That script is slow and also now exceeds the default call depth limit.
              # So, we memoize it here. It doesn't change anyway.
              [
              ${memo'd}
              ]
            '')
          ];
        };
      };

      packages = forAllSystems (system: packageSet inputs.nixpkgs.legacyPackages.${system});

      overlays.niri = (import ./files/overlay.nix { inherit inputs; }).overlays.niri;

      apps = forAllSystems (
        system:
        (builtins.mapAttrs (name: package: {
          type = "app";
          program = nixpkgs.lib.getExe package;
        }) (packageSet inputs.nixpkgs.legacyPackages.${system}))
        // {
          default = self.apps.${system}.niri-stable;
        }
      );

      formatter = forAllSystems (system: inputs.nixpkgs.legacyPackages.${system}.nixfmt-rfc-style);

      devShells = forAllSystems (system: {
        default = import ./shell.nix {
          flake = self;
          inherit system;
        };
      });

      nixosModules.niri = import ./files/nixos-module.nix {
        inherit inputs;
      };
      homeModules.niri = import ./files/home-module.nix;
      homeModules.config = import ./files/home-module-config.nix {
        inherit inputs;
      };
      homeModules.stylix = import ./files/stylix.nix;

      checks = forAllSystems (
        system:
        let
          test-nixos-for =
            nixpkgs: modules:
            (nixpkgs.lib.nixosSystem {
              inherit system;
              modules = [
                {
                  # This doesn't need to be a bootable system. It just needs to build.
                  system.stateVersion = "23.11";
                  fileSystems."/".fsType = "ext4";
                  fileSystems."/".device = "/dev/sda1";
                  boot.loader.systemd-boot.enable = true;
                }
              ]
              ++ modules;
            }).config.system.build.toplevel;
        in
        {
          cached-packages = cachedPackages inputs.nixpkgs system;
          empty-config-valid-stable =
            let
              eval = nixpkgs.lib.evalModules {
                modules = [
                  settings.module
                  {
                    config.programs.niri.settings = { };
                  }
                ];
              };
            in
            validateConfig inputs.nixpkgs.legacyPackages.${system} self.packages.${system}.niri-stable
              eval.config.programs.niri.finalConfig;

          nixos-unstable = test-nixos-for nixpkgs [
            self.nixosModules.niri
            {
              programs.niri.enable = true;
            }
          ];

          nixos-stable = test-nixos-for nixpkgs-stable [
            self.nixosModules.niri
            {
              programs.niri.enable = true;
            }
          ];
        }
      );
    };
}
