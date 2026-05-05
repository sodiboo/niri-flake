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
      combined-closure =
        pkgs-name: pkgs:
        pkgs.runCommand "niri-flake-packages-for-${pkgs-name}" { } (
          ''
            mkdir $out
          ''
          + builtins.concatStringsSep "" (
            nixpkgs.lib.mapAttrsToList (name: package: ''
              ln -s ${package} $out/${name}
            '') (nirilib.make-package-set pkgs)
          )
        );

      cached-packages-for =
        system:
        nixpkgs.legacyPackages.${system}.runCommand "all-niri-flake-packages" { } (
          ''
            mkdir $out
          ''
          + builtins.concatStringsSep "" (
            nixpkgs.lib.mapAttrsToList
              (name: nixpkgs': ''
                ln -s ${combined-closure name nixpkgs'.legacyPackages.${system}} $out/${name}
              '')
              {
                nixos-unstable = nixpkgs;
                "nixos-25.11" = nixpkgs-stable;
              }
          )
        );

      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];

      forAllSystems = nixpkgs.lib.genAttrs systems;
      nirilib = import ./lib.nix {
        inherit (nixpkgs) lib pkgs;
        inherit inputs;
      };
    in
    {
      lib = {
        inherit (nirilib) kdl;
        internal = {
          inherit (nirilib) make-package-set validated-config-for;
          package-set = abort "niri-flake internals: `package-set.\${package} pkgs` is now `(make-package-set pkgs).\${package}`";
          docs-markdown = nirilib.docs.make-docs (
            nirilib.settings.fake-docs { inherit (nirilib) fmt-date fmt-time; }
          );
          docs-html = nirilib.html-docs.make-docs (nirilib.settings.type-with nirilib.html-docs.settings-fmt);
          settings-module = nirilib.settings.module;
          memo-binds = nixpkgs.lib.pipe (nirilib.binds "${inputs.niri-unstable}/niri-config/src/binds.rs") [
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

      packages = forAllSystems (system: nirilib.make-package-set inputs.nixpkgs.legacyPackages.${system});

      overlays.niri = final: prev: import ./overlay.nix (final // { inherit inputs; }) prev;

      apps = forAllSystems (
        system:
        (builtins.mapAttrs (name: package: {
          type = "app";
          program = nixpkgs.lib.getExe package;
        }) (nirilib.make-package-set inputs.nixpkgs.legacyPackages.${system}))
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

      homeModules.stylix = ./modules/home-stylix.nix;
      homeModules.config = ./modules/home-config.nix;
      nixosModules.niri = ./modules/nixos.nix;
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
          cached-packages = cached-packages-for system;
          empty-config-valid-stable =
            let
              eval = nixpkgs.lib.evalModules {
                modules = [
                  nirilib.settings.module
                  {
                    config.programs.niri.settings = { };
                  }
                ];
              };
            in
            nirilib.validated-config-for inputs.nixpkgs.legacyPackages.${system}
              self.packages.${system}.niri-stable
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
