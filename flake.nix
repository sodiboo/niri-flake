{
  description = "A scrollable-tiling Wayland compositor.";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixpkgs-stable.url = "github:NixOS/nixpkgs/nixos-24.05";

    flake-parts.url = "github:hercules-ci/flake-parts";

    niri-unstable.url = "github:YaLTeR/niri";
    niri-unstable.flake = false;

    niri-stable.url = "github:YaLTeR/niri/v0.1.9";
    niri-stable.flake = false;

    xwayland-satellite-stable.url = "github:Supreeeme/xwayland-satellite/v0.4";
    xwayland-satellite-stable.flake = false;

    xwayland-satellite-unstable.url = "github:Supreeeme/xwayland-satellite";
    xwayland-satellite-unstable.flake = false;
  };

  outputs = inputs @ {
    self,
    flake-parts,
    nixpkgs,
    nixpkgs-stable,
    ...
  }: let
    call = nixpkgs.lib.flip import {
      inherit inputs kdl docs binds settings;
      inherit (nixpkgs) lib;
    };
    kdl = call ./kdl.nix;
    binds = call ./parse-binds.nix;
    docs = call ./generate-docs.nix;
    settings = call ./settings.nix;
    stylix-module = call ./stylix.nix;

    stable-revs = import ./refs.nix;

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

    version-string = orig-ver: src:
      if stable-revs ? ${src.rev}
      then "stable ${orig-ver}"
      else "unstable ${fmt-date src.lastModifiedDate} (commit ${src.rev})";

    package-version = orig-ver: src:
      if stable-revs ? ${src.rev}
      then orig-ver
      else "${orig-ver}-unstable-${src.shortRev}";

    make-niri = nixpkgs.lib.makeOverridable ({
      src,
      patches ? [],
      rustPlatform,
      pkg-config,
      wayland,
      systemdLibs,
      pipewire,
      mesa,
      libglvnd,
      seatd,
      libinput,
      libxkbcommon,
      libdisplay-info,
      pango,
    }: let
      manifest = builtins.fromTOML (builtins.readFile "${src}/Cargo.toml");
      workspace-version = manifest.workspace.package.version;
    in
      rustPlatform.buildRustPackage {
        pname = "niri";
        version = package-version workspace-version src;
        inherit src patches;
        cargoLock = {
          lockFile = "${src}/Cargo.lock";
          allowBuiltinFetchGit = true;
        };
        nativeBuildInputs = [
          pkg-config
          rustPlatform.bindgenHook
        ];

        buildInputs = [
          wayland
          systemdLibs
          pipewire
          mesa
          libglvnd
          seatd
          libinput
          libdisplay-info
          libxkbcommon
          pango
        ];

        passthru.providedSessions = ["niri"];

        # we want backtraces to be readable
        dontStrip = true;

        RUSTFLAGS = [
          "-C link-arg=-Wl,--push-state,--no-as-needed"
          "-C link-arg=-lEGL"
          "-C link-arg=-lwayland-client"
          "-C link-arg=-Wl,--pop-state"

          "-C debuginfo=line-tables-only"

          # "/source/" is not very readable. "./" is better, and it matches default behaviour of cargo.
          "--remap-path-prefix $NIX_BUILD_TOP/source=./"
        ];

        postPatch = ''
          substituteInPlace src/utils/mod.rs --replace ${nixpkgs.lib.escapeShellArgs [
            ''pub fn version() -> String {''
            ''
              #[allow(unreachable_code)]
              pub fn version() -> String {
                return "${version-string workspace-version src}".into();
            ''
          ]}
        '';

        postInstall = ''
          install -Dm0755 resources/niri-session -t $out/bin
          install -Dm0644 resources/niri.desktop -t $out/share/wayland-sessions
          install -Dm0644 resources/niri-portals.conf -t $out/share/xdg-desktop-portal
          install -Dm0644 resources/niri{-shutdown.target,.service} -t $out/share/systemd/user
        '';

        postFixup = ''
          substituteInPlace $out/share/systemd/user/niri.service --replace-fail /usr/bin $out/bin
        '';

        meta = with nixpkgs.lib; {
          description = "Scrollable-tiling Wayland compositor";
          homepage = "https://github.com/YaLTeR/niri";
          license = licenses.gpl3Only;
          maintainers = with maintainers; [sodiboo];
          mainProgram = "niri";
          platforms = platforms.linux;
        };
      });

    validated-config-for = pkgs: package: config:
      pkgs.runCommand "config.kdl" {
        inherit config;
        passAsFile = ["config"];
        buildInputs = [package];
      } ''
        niri validate -c $configPath
        cp $configPath $out
      '';

    make-xwayland-satellite = nixpkgs.lib.makeOverridable ({
      src,
      patches ? [],
      rustPlatform,
      pkg-config,
      makeWrapper,
      xwayland,
      xcb-util-cursor,
    }: let
      manifest = builtins.fromTOML (builtins.readFile "${src}/Cargo.toml");
      workspace-version = manifest.package.version;
    in
      rustPlatform.buildRustPackage {
        pname = "xwayland-satellite";
        version = package-version workspace-version src;
        inherit src patches;
        cargoLock = {
          lockFile = "${src}/Cargo.lock";
          allowBuiltinFetchGit = true;
        };
        nativeBuildInputs = [
          pkg-config
          rustPlatform.bindgenHook
        ];

        buildInputs = [
          xcb-util-cursor
          makeWrapper
        ];

        # All tests fail because runtime dir is not set
        doCheck = false;

        postInstall = ''
          wrapProgram $out/bin/xwayland-satellite \
            --prefix PATH : "${nixpkgs.lib.makeBinPath [xwayland]}"
        '';

        meta = with nixpkgs.lib; {
          description = "Rootless Xwayland integration to any Wayland compositor implementing xdg_wm_base";
          homepage = "https://github.com/Supreeeme/xwayland-satellite";
          license = licenses.mpl20;
          maintainers = with maintainers; [sodiboo];
          mainProgram = "xwayland-satellite";
          platforms = platforms.linux;
        };
      });

    package-set = {
      niri-stable = pkgs:
        pkgs.callPackage make-niri {
          src = inputs.niri-stable;
        };
      niri-unstable = pkgs:
        pkgs.callPackage make-niri {
          src = inputs.niri-unstable;
        };
      xwayland-satellite-stable = pkgs:
        pkgs.callPackage make-xwayland-satellite {
          src = inputs.xwayland-satellite-stable;
        };
      xwayland-satellite-unstable = pkgs:
        pkgs.callPackage make-xwayland-satellite {
          src = inputs.xwayland-satellite-unstable;
        };
    };

    combined-closure = pkgs-name: pkgs:
      pkgs.runCommand "niri-flake-packages-for-${pkgs-name}" {} (''
          mkdir $out
        ''
        + builtins.concatStringsSep "" (nixpkgs.lib.mapAttrsToList (name: make-for: ''
            ln -s ${make-for pkgs} $out/${name}
          '')
          package-set));

    cached = nixpkgs.legacyPackages.x86_64-linux.runCommand "all-niri-flake-packages" {} (''
        mkdir $out
      ''
      + builtins.concatStringsSep "" (nixpkgs.lib.mapAttrsToList (name: nixpkgs': ''
          ln -s ${combined-closure name nixpkgs'.legacyPackages.x86_64-linux} $out/${name}
        '') {
          nixos-unstable = nixpkgs;
          "nixos-24.05" = nixpkgs-stable;
        }));
  in
    flake-parts.lib.mkFlake {inherit inputs;} {
      systems = ["x86_64-linux" "aarch64-linux"];
      perSystem = {
        self',
        inputs',
        config,
        system,
        ...
      }: {
        packages =
          builtins.mapAttrs (
            name: make-for: make-for inputs'.nixpkgs.legacyPackages
          )
          package-set;

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

        checks = let
          test-nixos-for = nixpkgs: modules:
            (nixpkgs.lib.nixosSystem {
              inherit system;
              modules =
                [
                  {
                    # This doesn't need to be a bootable system. It just needs to build.
                    system.stateVersion = "23.11";
                    fileSystems."/".fsType = "ext4";
                    fileSystems."/".device = "/dev/sda1";
                    boot.loader.systemd-boot.enable = true;
                  }
                ]
                ++ modules;
            })
            .config
            .system
            .build
            .toplevel;
        in {
          empty-config-valid-stable = let
            eval = nixpkgs.lib.evalModules {
              modules = [
                settings.module
                {
                  config.programs.niri.settings = {};
                }
              ];
            };
          in
            validated-config-for inputs'.nixpkgs.legacyPackages self'.packages.niri-stable eval.config.programs.niri.finalConfig;

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
        };

        devShells.default = inputs'.nixpkgs.legacyPackages.mkShell {
          packages = with inputs'.nixpkgs.legacyPackages; [
            just
            fish
            fd
            entr
            moreutils
          ];

          shellHook = ''
            just hook 2>/dev/null
          '';
        };

        formatter = inputs'.nixpkgs.legacyPackages.alejandra;
      };

      flake = {
        overlays.niri = with nixpkgs.lib;
          final: prev: ((mapAttrs (const (flip id final)) package-set)
            // {
              xwayland-satellite-nixpkgs = prev.xwayland-satellite or abort "xwayland-satellite isn't in your nixpkgs";
              xwayland-satellite =
                nixpkgs.lib.warn ''
                  `pkgs.xwayland-satellite` will change behaviour in the future.

                  Previously, `pkgs.xwayland-satellite` was provided by this flake.
                  However, this (naively) overrides the version provided by nixpkgs.
                  Now, xwayland-satellite gets similar treatment to niri.
                  If you want to use the version you were previously using, use `pkgs.xwayland-satellite-unstable`.

                  For now, this is a warning and the behaviour is unchanged.
                  This invocation still uses the unstable version provided by this flake.

                  You can use the nixpkgs version explicitly by using `pkgs.xwayland-satellite-nixpkgs`.
                  That version will at a future point have a warning to switch back to `pkgs.xwayland-satellite` when that alias is removed from the overlay.
                ''
                final.xwayland-satellite-unstable;
            });
        lib = {
          inherit kdl;
          internal = {
            inherit package-set validated-config-for cached;
            docs-markdown = docs.make-docs (settings.fake-docs {inherit fmt-date fmt-time;});
            settings-module = settings.module;
          };
        };
        homeModules.stylix = stylix-module;
        homeModules.config = {
          config,
          pkgs,
          ...
        }:
          with nixpkgs.lib; let
            cfg = config.programs.niri;
          in {
            imports = [
              settings.module
            ];

            options.programs.niri = {
              package = mkOption {
                type = types.package;
                default = package-set.niri-stable pkgs;
              };
            };

            config.lib.niri = {
              actions = mergeAttrsList (map ({
                name,
                fn,
                ...
              }: {
                ${name} = fn;
              }) (binds cfg.package.src));
            };

            config.xdg.configFile.niri-config = {
              enable = cfg.finalConfig != null;
              target = "niri/config.kdl";
              source = validated-config-for pkgs cfg.package cfg.finalConfig;
            };
          };
        nixosModules.niri = {
          config,
          options,
          pkgs,
          ...
        }: let
          cfg = config.programs.niri;
        in
          with nixpkgs.lib; {
            options.programs.niri = {
              enable = mkEnableOption "niri";
              package = mkOption {
                type = types.package;
                default = package-set.niri-stable pkgs;
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
                services =
                  if nixpkgs.lib.strings.versionAtLeast config.system.nixos.release "24.05"
                  then {
                    displayManager.sessionPackages = [cfg.package];
                  }
                  else {
                    xserver.displayManager.sessionPackages = [cfg.package];
                  };
                hardware =
                  if nixpkgs.lib.strings.versionAtLeast config.system.nixos.release "24.11"
                  then {
                    graphics.enable = mkDefault true;
                  }
                  else {
                    opengl.enable = mkDefault true;
                  };
              })
              (mkIf cfg.enable {
                environment.systemPackages = [cfg.package];
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
          config,
          pkgs,
          ...
        }:
          with nixpkgs.lib; let
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
