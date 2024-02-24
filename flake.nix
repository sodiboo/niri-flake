{
  description = "A scrollable-tiling Wayland compositor.";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";

    crate2nix.url = "github:nix-community/crate2nix";

    niri-unstable.url = "github:YaLTeR/niri";
    niri-unstable.flake = false;

    niri-stable.url = "github:YaLTeR/niri/v0.1.2";
    niri-stable.flake = false;

    niri-src.url = "github:YaLTeR/niri/v0.1.2";
    niri-src.flake = false;
  };

  outputs = inputs @ {
    self,
    flake-parts,
    crate2nix,
    niri-unstable,
    niri-stable,
    niri-src,
    nixpkgs,
    ...
  }: let
    niri-src-is-unchanged = (builtins.fromJSON (builtins.readFile (self + /flake.lock))).nodes.niri-src.locked.rev == niri-src.rev;

    make-niri-overridable = nixpkgs.lib.makeOverridable ({
      src,
      pkgs,
    }: let
      tools = crate2nix.tools.${pkgs.stdenv.system};
      manifest = tools.generatedCargoNix {
        inherit src;
        name = "niri";
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

                # For all niri crates, the hash of the source is different in CI than on my system.
                # KiaraGrouwstra reports identical hash to my system, so it really is only in CI.
                #
                # We suspect it might be due to the fact that CI uses a different version of nix.
                # But that shouldn't matter, because the hash is not derived from the nix version used!
                # It might also be some symptom of import-from-derivation, but i don't care to investigate.
                #
                # Ultimately, the solution looks stupid, but it does work:
                # Just override `src` attr to be the correct path based on the `src` argument.
                # This causes them to be predictable and based on the flake inputs, which is what we want.
                #
                # Everything builds the same way without this. But the hash is different.
                # And for binary caching to work, the hash must be identical.
                niri-ipc = attrs: {
                  src = "${src}/niri-ipc";
                };

                niri-config = attrs: {
                  src = "${src}/niri-config";
                  prePatch = "substituteInPlace src/lib.rs --replace ../.. ${src}";
                };

                niri = attrs: {
                  src = "${src}";
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
                    mkdir -p $out/share/systemd/user
                    mkdir -p $out/share/wayland-sessions
                    mkdir -p $out/share/xdg-desktop-portal

                    cp ${src}/resources/niri-session $out/bin/niri-session
                    cp ${src}/resources/niri.service $out/share/systemd/user/niri.service
                    cp ${src}/resources/niri-shutdown.target $out/share/systemd/user/niri-shutdown.target
                    cp ${src}/resources/niri.desktop $out/share/wayland-sessions/niri.desktop
                    cp ${src}/resources/niri-portals.conf $out/share/xdg-desktop-portal/niri-portals.conf
                  '';

                  postFixup = "substituteInPlace $out/share/systemd/user/niri.service --replace /usr $out";
                };
              });
          };
      };
    in
      workspace.workspaceMembers.niri.build // {inherit workspace;});

    make-niri = pkgs: src: make-niri-overridable {inherit src pkgs;};
  in
    flake-parts.lib.mkFlake {inherit inputs;} {
      systems = ["x86_64-linux" "aarch64-linux"];
      perSystem = {
        self',
        config,
        system,
        pkgs,
        ...
      }: {
        packages = {
          niri-unstable = make-niri pkgs niri-unstable;
          niri-stable = make-niri pkgs niri-stable;

          niri =
            nixpkgs.lib.warn
            ''
              Usage of `niri.packages.${system}.niri is deprecated.
              Use `niri.packages.${system}.niri-stable` or `niri.packages.${system}.niri-unstable` instead.
              If you must use a specific revision, override them with the `src` parameter.

              See the README for more details and recommended setup.
            '' (make-niri pkgs niri-src);
          default = self'.packages.niri;
        };

        apps = {
          niri-stable = {
            type = "app";
            program = "${self'.packages.niri-stable}/bin/niri";
          };
          niri-unstable = {
            type = "app";
            program = "${self'.packages.niri-unstable}/bin/niri";
          };

          default = self'.apps.niri-stable;
        };

        formatter = pkgs.alejandra;
      };

      flake = {
        overlays.niri = final: prev: {
          niri-unstable = make-niri final niri-unstable;
          niri-stable = make-niri final niri-stable;
        };
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
                default = make-niri pkgs niri-src;
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
                default = make-niri {
                  inherit pkgs;
                  src = niri-stable;
                };
              };

              acknowledge-warning.will-use-nixpkgs = mkOption {
                type = types.bool;
                default = false;
              };
            };

            config = mkMerge [
              (mkIf (!niri-src-is-unchanged) {
                warnings = [
                  ''
                    Don't override `niri.inputs.niri-src`. This input will be removed in the future.
                    You should use the `niri-stable` and `niri-unstable` packages instead.
                    See the README for more details.

                    If you must use a specific revision, create your own input instead.
                    Then, use the package `niri-unstable.override { src = my-niri-src; }`.
                  ''
                ];
              })
              (mkIf cfg.acknowledge-warning.will-use-nixpkgs {
                warnings = [
                  ''
                    Unset programs.niri.acknowledge-warning.will-use-nixpkgs.

                    nixpkgs niri will *not* be the default, given that binary caching has been implemented prior to their merging of v0.1.2.

                    the option to acknowledge the warning will be removed, as the warning it acknowledges is already gone.
                  ''
                ];
              })
              {
                environment.systemPackages = [pkgs.xdg-utils];
                xdg = {
                  autostart.enable = mkDefault true;
                  menus.enable = mkDefault true;
                  mime.enable = mkDefault true;
                  icons.enable = mkDefault true;
                };
              }
              (mkIf cfg.enable {
                environment.systemPackages = [cfg.package];
                services.xserver.displayManager.sessionPackages = [cfg.package];
                xdg.portal = {
                  enable = true;
                  extraPortals = [pkgs.xdg-desktop-portal-gnome];
                  configPackages = [cfg.package];
                };

                security.polkit.enable = true;
                services.gnome.gnome-keyring.enable = true;
                systemd.user.services.niri-flake-polkit = {
                  description = "PolicyKit Authentication Agent provided by niri-flake";
                  wantedBy = ["niri.service"];
                  wants = ["graphical-session.target"];
                  after = ["graphical-session.target"];
                  serviceConfig = {
                    Type = "simple";
                    ExecStart = "${pkgs.libsForQt5.polkit-kde-agent}/libexec/polkit-kde-authentication-agent-1";
                    Restart = "on-failure";
                    RestartSec = 1;
                    TimeoutStopSec = 10;
                  };
                };

                security.pam.services.swaylock = {};
                hardware.opengl.enable = mkDefault true;
                programs.dconf.enable = mkDefault true;
                fonts.enableDefaultPackages = mkDefault true;
              })
              (optionalAttrs (options ? home-manager) {
                home-manager.sharedModules = [
                  self.homeModules.config
                  {
                    programs.niri.package = mkForce cfg.package;
                  }
                ];
              })
            ];
          };
        nixosModules.default =
          nixpkgs.lib.warn ''
            Do not use niri.nixosModules.default.
            Use niri.nixosModules.niri instead.
          ''
          self.nixosModules.niri;
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
