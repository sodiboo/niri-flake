{
  description = "A scrollable-tiling Wayland compositor.";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";

    crate2nix.url = "github:nix-community/crate2nix";

    niri-src.url = "github:YaLTeR/niri/v0.1.1";
    niri-src.flake = false;
  };

  outputs = inputs @ {
    self,
    flake-parts,
    crate2nix,
    niri-src,
    nixpkgs,
    ...
  }:
    flake-parts.lib.mkFlake {inherit inputs;} {
      systems = ["x86_64-linux" "aarch64-linux"];
      perSystem = {
        self',
        config,
        system,
        pkgs,
        ...
      }: let
        tools = pkgs.callPackage "${crate2nix}/tools.nix" {};

        manifest = tools.generatedCargoNix {
          name = "niri";
          src = niri-src;
        };

        workspace = import manifest {
          inherit pkgs;
          buildRustCrateForPkgs = pkgs:
            pkgs.buildRustCrate.override {
              defaultCrateOverrides =
                pkgs.defaultCrateOverrides
                // (with pkgs; {
                  libspa-sys = attrs: {
                    nativeBuildInputs = [pkg-config rustPlatform.bindgenHook];
                    buildInputs = [pipewire];
                  };

                  libspa = attrs: {
                    nativeBuildInputs = [pkg-config];
                    buildInputs = [pipewire];
                  };

                  pipewire-sys = attrs: {
                    nativeBuildInputs = [pkg-config rustPlatform.bindgenHook];
                    buildInputs = [pipewire];
                  };

                  gobject-sys = attrs: {
                    nativeBuildInputs = [pkg-config glib];
                  };

                  gio-sys = attrs: {
                    nativeBuildInputs = [pkg-config glib];
                  };

                  niri-config = attrs: {
                    prePatch = ''sed -i 's#\.\./\.\.#${niri-src}#' src/lib.rs'';
                  };

                  niri = attrs: {
                    buildInputs = [libxkbcommon libinput mesa libglvnd wayland pixman];

                    # we want backtraces to be readable
                    dontStrip = true;

                    extraRustcOpts = [
                      "-C link-arg=-Wl,--push-state,--no-as-needed"
                      "-C link-arg=-lEGL"
                      "-C link-arg=-lwayland-client"
                      "-C link-arg=-Wl,--pop-state"

                      "-C debuginfo=line-tables-only"

                      # "/source/" is not very readable. "./" is better, and it matches default behaviour of cargo.
                      "--remap-path-prefix $NIX_BUILD_TOP/source=./"
                    ];

                    passthru.providedSessions = ["niri"];

                    postInstall = ''
                      mkdir -p $out/lib/systemd/user
                      mkdir -p $out/share/wayland-sessions
                      mkdir -p $out/share/xdg-desktop-portal

                      cp ${niri-src}/resources/niri-session $out/bin/niri-session
                      cp ${niri-src}/resources/niri.service $out/lib/systemd/user/niri.service
                      cp ${niri-src}/resources/niri-shutdown.target $out/lib/systemd/user/niri-shutdown.target
                      cp ${niri-src}/resources/niri.desktop $out/share/wayland-sessions
                      cp ${niri-src}/resources/niri-portals.conf $out/share/xdg-desktop-portal/niri-portals.conf
                    '';

                    postFixup = ''sed -i "s#/usr#$out#" $out/lib/systemd/user/niri.service'';
                  };
                });
            };
        };
      in {
        packages = {
          niri =
            workspace.workspaceMembers.niri.build // {
              inherit workspace;
            };
          default = self'.packages.niri;
        };

        apps = {
          niri = {
            type = "app";
            program = "${self'.packages.niri}/bin/niri";
          };
          default = self'.apps.niri;
        };

        formatter = pkgs.alejandra;
      };

      flake = {
        homeModules.config = {
          lib,
          config,
          pkgs,
          ...
        }:
          with lib; let
            packages = self.packages.${pkgs.stdenv.system};
            cfg = config.programs.niri;
          in {
            options.programs.niri = {
              config = mkOption {
                default = null;
                type = types.nullOr types.str;
              };
            };

            config.xdg.configFile.niri-config = {
              enable = !isNull cfg.config;
              target = "niri/config.kdl";
              source =
                pkgs.runCommand "config.kdl" {
                  config = cfg.config;
                  passAsFile = ["config"];
                  buildInputs = [packages.niri];
                } ''
                  niri validate -c $configPath
                  cp $configPath $out
                '';
            };
          };
        nixosModules.niri = {
          lib,
          config,
          options,
          pkgs,
          ...
        }: let
          packages = self.packages.${pkgs.stdenv.targetPlatform.system};
          cfg = config.programs.niri;
        in
          with lib; {
            options.programs.niri = {
              enable = mkEnableOption "niri";
            };

            config = mkMerge [
              (mkIf cfg.enable {
                environment.systemPackages = [packages.niri];
                services.xserver.displayManager.sessionPackages = [packages.niri];
                systemd.packages = [packages.niri];
                services.gnome.gnome-keyring.enable = true;
                xdg.portal = {
                  enable = true;
                  extraPortals = [pkgs.xdg-desktop-portal-gnome];
                  configPackages = [packages.niri];
                };
              })
              (optionalAttrs (options ? home-manager) {
                home-manager.sharedModules = [
                  self.homeModules.config
                ];
              })
            ];
          };
        nixosModules.default = self.nixosModules.niri;
        homeModules.niri = {
          lib,
          config,
          pkgs,
          ...
        }:
          with lib; let
            packages = self.packages.${pkgs.stdenv.system};
            cfg = config.programs.niri;
          in {
            imports = [
              self.homeModules.config
            ];
            options.programs.niri = {
              enable = mkEnableOption "niri";
            };

            config = mkIf cfg.enable {
              home.packages = [packages.niri];

              xdg.configFile = builtins.listToAttrs (map (unit: {
                name = unit;
                value = rec {
                  enable = true;
                  target = "systemd/user/${unit}";
                  source = "${packages.niri}/lib/${target}";
                };
              }) ["niri.service" "niri-shutdown.target"]);

              xdg.portal = {
                enable = true;
                extraPortals = [pkgs.xdg-desktop-portal-gnome];
                configPackages = [packages.niri];
              };
            };
          };
      };
    };
}
