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
  };

  outputs = inputs @ {
    self,
    flake-parts,
    crate2nix,
    niri-unstable,
    niri-stable,
    nixpkgs,
    ...
  }: let
    kdl = import ./kdl.nix {inherit (nixpkgs) lib;};

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
                # Q: Why do we need to override these?
                #    (nixpkgs)/(niri's dev flake) doesn't do this!
                #
                # A: crate2nix builds each crate in a separate derivation.
                #    This is to avoid building the same crate multiple times.
                #    Ultimately, that speeds up the build.
                #    But it also means that each crate has separate build inputs.
                #
                #    Many popular crates have "default overrides" in nixpkgs.
                #    But it doesn't cover all crates niri depends on.
                #    So we need to fix those last few ourselves.
                #
                #    (nixpkgs)/(niri's dev flake) uses `cargo` to build.
                #    And this builds all crates in the same derivation.
                #    That's why they don't override individual crates.
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
                  prePatch = "substituteInPlace src/lib.rs --replace-fail ../.. ${src}";
                };

                niri = attrs: {
                  src = "${src}";
                  # this is kind of a hack. i'm not sure how to handle the paths properly
                  # i tried various things: *.rs, **.rs, **/*.rs, src/*.rs, src/**.rs, src/**/*.rs
                  # but ultimately, none of them (from what i can tell) works on stable and unstable.
                  # as i write this, the file of interest has moved files between the two branches.
                  # so no single absolute file path works.
                  # i may have missed something. some of the above probably works on its own.
                  # but it takes like 10 mins to rebuild niri on both branches on my laptop
                  # and i don't have the patience to test all of them thoroughly.
                  # this one works. one path is for stable, one is for unstable
                  # i use --replace-quiet because if it doesn't work, --version will say "unknown commit"
                  # which is not that bad, and not worth aborting builds for.
                  # if i was packaging only stable, this would be trivial to implement.
                  # but ultimately, unstable is the one where this matters more.
                  prePatch =
                    "substituteInPlace src/**.rs src/**/*.rs --replace-quiet "
                    + nixpkgs.lib.escapeShellArgs [
                      ''git_version!(fallback = "unknown commit")''
                      ''"niri-flake at ${src.shortRev}"''
                    ];
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

                  postFixup = "substituteInPlace $out/share/systemd/user/niri.service --replace-fail /usr $out";
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
        inherit kdl;
        overlays.niri = final: prev: {
          niri-unstable = make-niri final niri-unstable;
          niri-stable = make-niri final niri-stable;
        };
        homeModules.experimental-settings = import ./settings.nix {inherit kdl;};
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
                type = types.nullOr (types.either types.str kdl.types.kdl-nodes);
                default = null;
              };
              package = mkOption {
                type = types.package;
                default = make-niri pkgs niri-stable;
              };
            };

            config.xdg.configFile.niri-config = {
              enable = cfg.config != null;
              target = "niri/config.kdl";
              source =
                pkgs.runCommand "config.kdl" {
                  config =
                    if isString cfg.config
                    then cfg.config
                    else kdl.serialize.nodes cfg.config;
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
                default = make-niri pkgs niri-stable;
              };
            };

            options.niri-flake.cache.enable = mkOption {
              type = types.bool;
              default = true;
            };

            config = mkMerge [
              (mkIf config.niri-flake.cache.enable {
                nix.settings = {
                  substituters = ["https://niri.cachix.org"];
                  trusted-public-keys = ["niri.cachix.org-1:Wv0OmO7PsuocRKzfDoJ3mulSl7Z6oezYhGhR+3W2964="];
                };
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
