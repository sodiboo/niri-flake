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

        makeWorkspace = {pkgs}:
          import manifest {
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
          niri = pkgs.lib.makeOverridable (args: let
            workspace = makeWorkspace args;
          in
            workspace.workspaceMembers.niri.build // {inherit workspace;})
          {inherit pkgs;};
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
            cfg = config.programs.niri;
          in {
            options.programs.niri = {
              config = mkOption {
                type = types.nullOr types.str;
                default = null;
              };
              package = mkOption {
                type = types.package;
                default = self.packages.${pkgs.stdenv.system}.niri.override {inherit pkgs;};
              };
            };

            config.xdg.configFile.niri-config = {
              enable = !isNull cfg.config;
              target = "niri/config.kdl";
              source =
                pkgs.runCommand "config.kdl" {
                  config = cfg.config;
                  passAsFile = ["config"];
                  buildInputs = [cfg.package];
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
          cfg = config.programs.niri;
        in
          with lib; {
            options.programs.niri = {
              enable = mkEnableOption "niri";
              package = mkOption {
                type = types.package;
                default = self.packages.${pkgs.stdenv.system}.niri.override {inherit pkgs;};
              };
            };

            config = mkMerge [
              (mkIf cfg.enable {
                environment.systemPackages = [cfg.package];
                services.xserver.displayManager.sessionPackages = [cfg.package];
                services.gnome.gnome-keyring.enable = true;
                xdg.portal = {
                  enable = true;
                  extraPortals = [pkgs.xdg-desktop-portal-gnome];
                  configPackages = [cfg.package];
                };
              })
              (optionalAttrs (options ? home-manager) {
                home-manager.sharedModules = [
                  self.homeModules.config
                  {
                    programs.niri.package = cfg.package;
                  }
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
            cfg = config.programs.niri;
          in {
            imports = [
              self.homeModules.config
            ];
            options.programs.niri = {
              enable = mkEnableOption "niri";
            };

            config = mkIf cfg.enable {
              home.packages = [cfg.package];
              services.gnome-keyring.enable = true;
              xdg.portal = {
                enable = true;
                extraPortals = [pkgs.xdg-desktop-portal-gnome];
                configPackages = [cfg.package];
              };
            };
          };
      };
    };
}
