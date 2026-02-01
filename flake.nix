{
  description = "A scrollable-tiling Wayland compositor.";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixpkgs-stable.url = "github:NixOS/nixpkgs/nixos-25.11";
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
          inputs
          kdl
          docs
          binds
          settings
          ;
        inherit (nixpkgs) lib;
      };
      kdl = call ./kdl.nix;
      binds = call ./parse-binds.nix;
      docs = call ./generate-docs.nix;
      html-docs = call ./generate-html-docs.nix;
      settings = call ./settings.nix;
      stylix-module = call ./stylix.nix;

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

      validated-config-for =
        pkgs: package: config:
        pkgs.runCommand "config.kdl"
          {
            inherit config;
            passAsFile = [ "config" ];
            buildInputs = [ package ];
          }
          ''
            niri validate -c $configPath
            cp $configPath $out
          '';

      make-package-set = pkgs: {
        niri-stable = pkgs.callPackage ./pkgs/niri/stable { };
        niri-unstable = pkgs.callPackage ./pkgs/niri/unstable { };
        xwayland-satellite-stable = pkgs.callPackage ./pkgs/xwayland-satellite/stable { };
        xwayland-satellite-unstable = pkgs.callPackage ./pkgs/xwayland-satellite/unstable { };
      };

      combined-closure =
        pkgs-name: pkgs:
        pkgs.runCommand "niri-flake-packages-for-${pkgs-name}" { } (
          ''
            mkdir $out
          ''
          + builtins.concatStringsSep "" (
            nixpkgs.lib.mapAttrsToList (name: package: ''
              ln -s ${package} $out/${name}
            '') (make-package-set pkgs)
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
    in
    {
      lib = {
        inherit kdl;
        internal = {
          inherit make-package-set validated-config-for;
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

      packages = forAllSystems (system: make-package-set inputs.nixpkgs.legacyPackages.${system});

      overlays.niri = final: prev: make-package-set final;

      apps = forAllSystems (
        system:
        (builtins.mapAttrs (name: package: {
          type = "app";
          program = nixpkgs.lib.getExe package;
        }) (make-package-set inputs.nixpkgs.legacyPackages.${system}))
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

      homeModules.stylix = stylix-module;
      homeModules.config =
        {
          config,
          pkgs,
          ...
        }:
        let
          cfg = config.programs.niri;
        in
        {
          imports = [
            settings.module
          ];

          options.programs.niri = {
            package = nixpkgs.lib.mkOption {
              type = nixpkgs.lib.types.package;
              default = (make-package-set pkgs).niri-stable;
              description = "The niri package to use.";
            };
          };

          config.lib.niri = {
            actions = nixpkgs.lib.mergeAttrsList (
              map (name: {
                ${name} = kdl.magic-leaf name;
              }) (import ./memo-binds.nix)
            );
          };

          config.xdg.configFile.niri-config = {
            enable = cfg.finalConfig != null;
            target = "niri/config.kdl";
            source = validated-config-for pkgs cfg.package cfg.finalConfig;
          };
        };
      nixosModules.niri =
        {
          config,
          options,
          pkgs,
          ...
        }:
        let
          cfg = config.programs.niri;
        in
        {
          # The module from this flake predates the module in nixpkgs by a long shot.
          # To avoid conflicts, we disable the nixpkgs module.
          # Eventually, this module (e.g. `niri.nixosModules.niri`) will be deprecated
          # in favour of other modules that aren't redundant with nixpkgs (and don't yet exist)
          disabledModules = [ "programs/wayland/niri.nix" ];

          options.programs.niri = {
            enable = nixpkgs.lib.mkEnableOption "niri";
            package = nixpkgs.lib.mkOption {
              type = nixpkgs.lib.types.package;
              default = (make-package-set pkgs).niri-stable;
              description = "The niri package to use.";
            };
          };

          options.niri-flake.cache.enable = nixpkgs.lib.mkEnableOption "the niri-flake binary cache" // {
            default = true;
          };

          config = nixpkgs.lib.mkMerge [
            (nixpkgs.lib.mkIf config.niri-flake.cache.enable {
              nix.settings = {
                substituters = [ "https://niri.cachix.org" ];
                trusted-public-keys = [ "niri.cachix.org-1:Wv0OmO7PsuocRKzfDoJ3mulSl7Z6oezYhGhR+3W2964=" ];
              };
            })
            (nixpkgs.lib.mkIf cfg.enable {
              environment.systemPackages = [
                pkgs.xdg-utils
                cfg.package
              ];
              xdg = {
                autostart.enable = nixpkgs.lib.mkDefault true;
                menus.enable = nixpkgs.lib.mkDefault true;
                mime.enable = nixpkgs.lib.mkDefault true;
                icons.enable = nixpkgs.lib.mkDefault true;
              };

              services.displayManager.sessionPackages = [ cfg.package ];
              hardware.graphics.enable = nixpkgs.lib.mkDefault true;

              xdg.portal = {
                enable = true;
                extraPortals = nixpkgs.lib.mkIf (
                  !cfg.package.cargoBuildNoDefaultFeatures
                  || builtins.elem "xdp-gnome-screencast" cfg.package.cargoBuildFeatures
                ) [ pkgs.xdg-desktop-portal-gnome ];
                configPackages = [ cfg.package ];
              };

              security.polkit.enable = true;
              services.gnome.gnome-keyring.enable = true;
              systemd.user.services.niri-flake-polkit = {
                description = "PolicyKit Authentication Agent provided by niri-flake";
                wantedBy = [ "niri.service" ];
                after = [ "graphical-session.target" ];
                partOf = [ "graphical-session.target" ];
                serviceConfig = {
                  Type = "simple";
                  ExecStart = "${pkgs.kdePackages.polkit-kde-agent-1}/libexec/polkit-kde-authentication-agent-1";
                  Restart = "on-failure";
                  RestartSec = 1;
                  TimeoutStopSec = 10;
                };
              };

              security.pam.services.swaylock = { };
              programs.dconf.enable = nixpkgs.lib.mkDefault true;
              fonts.enableDefaultPackages = nixpkgs.lib.mkDefault true;
            })
            (nixpkgs.lib.optionalAttrs (options ? home-manager) {
              home-manager.sharedModules = [
                self.homeModules.config
                { programs.niri.package = nixpkgs.lib.mkForce cfg.package; }
              ]
              ++ nixpkgs.lib.optionals (options ? stylix) [ self.homeModules.stylix ];
            })
          ];
        };
      homeModules.niri =
        {
          config,
          pkgs,
          ...
        }:
        let
          cfg = config.programs.niri;
        in
        {
          imports = [
            self.homeModules.config
          ];
          options.programs.niri = {
            enable = nixpkgs.lib.mkEnableOption "niri";
          };

          config = nixpkgs.lib.mkIf cfg.enable {
            home.packages = [ cfg.package ];
            services.gnome-keyring.enable = true;
            xdg.portal = {
              enable = true;
              extraPortals = nixpkgs.lib.mkIf (
                !cfg.package.cargoBuildNoDefaultFeatures
                || builtins.elem "xdp-gnome-screencast" cfg.package.cargoBuildFeatures
              ) [ pkgs.xdg-desktop-portal-gnome ];
              configPackages = [ cfg.package ];
            };
          };
        };

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
                  settings.module
                  {
                    config.programs.niri.settings = { };
                  }
                ];
              };
            in
            validated-config-for inputs.nixpkgs.legacyPackages.${system} self.packages.${system}.niri-stable
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
