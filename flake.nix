{
  description = "A scrollable-tiling Wayland compositor.";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";

    crate2nix.url = "github:nix-community/crate2nix";

    niri-unstable.url = "github:YaLTeR/niri";
    niri-unstable.flake = false;

    niri-stable.url = "github:YaLTeR/niri/v0.1.3";
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
    call = nixpkgs.lib.flip import {
      inherit inputs kdl docs binds;
      inherit (nixpkgs) lib;
    };
    kdl = call ./kdl.nix;
    binds = call ./parse-binds.nix;
    docs = call ./generate-docs.nix;
    settings = call ./settings.nix;
    stylix-module = call ./stylix.nix;

    lock = builtins.fromJSON (builtins.readFile ./flake.lock);
    stable-tag = lock.nodes.niri-stable.original.ref;
    stable-rev = lock.nodes.niri-stable.locked.rev;

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

    version-string = src:
      if src.rev == stable-rev
      then "stable ${stable-tag}"
      else "unstable ${fmt-date src.lastModifiedDate} (commit ${src.rev})";

    make-niri = nixpkgs.lib.makeOverridable ({
      src,
      pkgs,
      patches ? [],
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
                  postPatch = "substituteInPlace src/lib.rs --replace ../.. ${src}";
                };

                niri = attrs: {
                  src = "${src}";

                  inherit patches;

                  postPatch =
                    "substituteInPlace src/utils/mod.rs --replace "
                    + nixpkgs.lib.escapeShellArgs [
                      ''pub fn version() -> String {''
                      ''
                        #[allow(unreachable_code)]
                        pub fn version() -> String {
                          return "${version-string src}".into();
                      ''
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

                  postFixup = "substituteInPlace $out/share/systemd/user/niri.service --replace /usr $out";
                };
              });
          };
      };
    in
      workspace.workspaceMembers.niri.build
      // {
        binds = binds src;
        inherit workspace;
      });

    make-niri-stable = pkgs:
      make-niri {
        inherit pkgs;
        src = niri-stable;
        patches = [
          (pkgs.fetchpatch {
            name = "revert-viewporter.patch";
            url = "https://github.com/YaLTeR/niri/commit/40cec34aa4a7f99ab12b30cba1a0ee83a706a413.patch";
            hash = "sha256-3fg8v0eotfjUQY6EVFEPK5BBIBrr6vQpXbjDcsw2E8Q=";
          })
        ];
      };

    make-niri-unstable = pkgs:
      make-niri {
        inherit pkgs;
        src = niri-unstable;
      };
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
          niri-unstable = make-niri-unstable pkgs;
          niri-stable = make-niri-stable pkgs;
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
        __docs = (docs.make-docs (settings.fake-docs {inherit stable-tag fmt-date fmt-time nixpkgs;}));
        inherit kdl;
        overlays.niri = final: prev: {
          niri-unstable = make-niri-unstable final;
          niri-stable = make-niri-stable final;
        };
        homeModules.stylix = stylix-module;
        homeModules.config = {
          lib,
          config,
          pkgs,
          ...
        }:
          with lib; let
            cfg = config.programs.niri;
          in {
            imports = [
              settings.module
            ];

            options.programs.niri = {
              package = mkOption {
                type = types.package;
                default = make-niri-stable pkgs;
              };
            };

            config.xdg.configFile.niri-config = {
              enable = cfg.finalConfig != null;
              target = "niri/config.kdl";
              source =
                pkgs.runCommand "config.kdl" {
                  config = cfg.finalConfig;
                  passAsFile = ["config"];
                  buildInputs = [cfg.package];
                } ''
                  niri validate -c $configPath
                  cp $configPath $out
                '';
            };

            config.warnings =
              pipe {
                # the prefix here helps ensure that the cartesian product is taken in the correct order
                a_decoration = ["border" "focus-ring"];
                b_state = ["active" "inactive"];
                c_field = ["color" "gradient"];
              } [
                cartesianProductOfSets
                (map (concatMapAttrs (name: value: {${substring 2 (stringLength name - 2) name} = value;})))
                (filter ({
                  decoration,
                  state,
                  field,
                }:
                  cfg.settings.layout.${decoration}."${state}-${field}" or null != null))
                (used:
                  mkIf (used != []) [
                    ''

                      Usage of deprecated options:

                      ${concatStrings (forEach used ({
                        decoration,
                        state,
                        field,
                        ...
                      }: ''
                        - `programs.niri.settings.layout.${decoration}.${state}-${field}`
                      ''))}
                      They will be removed in a future version.
                      The reasoning for this is that the previous structure is incorrectly typed.

                      They are superseded by the following options:

                      ${concatStrings (forEach used ({
                        decoration,
                        state,
                        field,
                        ...
                      }: ''
                        - `programs.niri.settings.layout.${decoration}.${state}.${field}`
                      ''))}
                      Note that you cannot set `color` and `gradient` for the same field anymore.
                      Previously, the gradient always took priority when non-null.
                    ''
                  ])
              ];
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
                default = make-niri-stable pkgs;
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
                home-manager.sharedModules =
                  [
                    self.homeModules.config
                    {programs.niri.package = mkForce cfg.package;}
                  ]
                  ++ optionals (options ? stylix) [self.homeModules.stylix];
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
