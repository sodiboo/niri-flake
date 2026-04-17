{
  description = "A scrollable-tiling Wayland compositor.";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    niri.url = "github:YaLTeR/niri";
    xwayland-satellite.url = "github:Supreeeme/xwayland-satellite";

    niri.flake = false;
    xwayland-satellite.flake = false;
  };

  outputs =
    inputs@{
      self,
      nixpkgs,
      ...
    }:
    let
      call = nixpkgs.lib.flip import {
inherit
          kdl
          ;
        inherit (nixpkgs) lib;
      };
      kdl = call ./kdl.nix;

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

      version-string =
        src:
        "niri ${fmt-date src.lastModifiedDate} (commit ${src.rev})";

      package-version =
        src:
        "${fmt-date src.lastModifiedDate}-${src.shortRev}";

      make-niri =
        {
          src,
          patches ? [ ],
          rustPlatform,
          pkg-config,
          installShellFiles,
          wayland,
          systemdLibs,
          eudev,
          pipewire,
          libgbm,
          libglvnd,
          seatd,
          libinput,
          libxkbcommon,
          libdisplay-info_0_2 ? libdisplay-info,
          libdisplay-info,
          pango,
          withDbus ? true,
          withDinit ? false,
          withScreencastSupport ? true,
          withSystemd ? true,
          fetchzip,
          runCommand,
        }:
        rustPlatform.buildRustPackage {
          pname = "niri";
          version = package-version src;
          src = src;
          inherit patches;
          cargoLock = {
            lockFile = "${src}/Cargo.lock";
            allowBuiltinFetchGit = true;
          };
          nativeBuildInputs = [
            pkg-config
            rustPlatform.bindgenHook
            installShellFiles
          ];

          buildInputs = [
            wayland
            libgbm
            libglvnd
            seatd
            libinput
            libdisplay-info_0_2
            libxkbcommon
            pango
          ]
          ++ nixpkgs.lib.optional withScreencastSupport pipewire
          ++ nixpkgs.lib.optional withSystemd systemdLibs # we only need udev, really.
          ++ nixpkgs.lib.optional (!withSystemd) eudev; # drop-in replacement for systemd-udev

          checkFlags = [
            # Some tests require surfaceless OpenGL displays. The "surfaceless" part means we don't need a Wayland or Xorg server;
            # but they still fundamentally require GPU drivers, which are only (sometimes) present at runtime.
            "--skip=::egl"
          ];

          buildNoDefaultFeatures = true;
          buildFeatures =
            nixpkgs.lib.optional withDbus "dbus"
            ++ nixpkgs.lib.optional withDinit "dinit"
            ++ nixpkgs.lib.optional withScreencastSupport "xdp-gnome-screencast"
            ++ nixpkgs.lib.optional withSystemd "systemd";

          passthru.providedSessions = [ "niri" ];

          # we want backtraces to be readable
          dontStrip = true;

          RUSTFLAGS = [
            "-C link-arg=-Wl,--push-state,--no-as-needed"
            "-C link-arg=-lEGL"
            "-C link-arg=-lwayland-client"
            "-C link-arg=-Wl,--pop-state"

            "-C debuginfo=line-tables-only"
          ];

          NIRI_BUILD_VERSION_STRING = version-string src;

          outputs = [
            "out"
            "doc"
          ];

          # previously, the second line was part of RUSTFLAGS above
          # but i noticed it stopped working? because it doesn't interpolate the env var anymore.
          #
          # i don't know when or why it stopped working. but moving it here fixes it.
          # the first line was unnecessary previously because this should be the default
          # https://github.com/NixOS/nixpkgs/blob/11cf80ae321c35132c1aff950f026e9783f06fec/pkgs/build-support/rust/build-rust-crate/build-crate.nix#L19
          # but for some reason it isn't. so i'm doing it manually.
          #
          # the purpose is to make backtraces more readable. the first line strips the useless `/build` prefix
          # and the second line makes niri-related paths more obvious as if they were based on pwd with `cargo run`
          postPatch = ''
            export RUSTFLAGS="$RUSTFLAGS --remap-path-prefix $NIX_BUILD_TOP=/"
            export RUSTFLAGS="$RUSTFLAGS --remap-path-prefix $NIX_BUILD_TOP/source=./"

            patchShebangs resources/niri-session
          '';

          postInstall =
            # niri.desktop calls `niri-session` and that executable only works with systemd or dinit
            nixpkgs.lib.optionalString (withSystemd || withDinit) ''
              install -Dm0755 resources/niri-session -t $out/bin
              install -Dm0644 resources/niri.desktop -t $out/share/wayland-sessions
            ''
            # any of these features will enable dbus support
            + nixpkgs.lib.optionalString (withDbus || withScreencastSupport || withSystemd) ''
              install -Dm0644 resources/niri-portals.conf -t $out/share/xdg-desktop-portal
            ''
            + nixpkgs.lib.optionalString withSystemd ''
              install -Dm0644 resources/niri{-shutdown.target,.service} -t $out/lib/systemd/user
            ''
            + nixpkgs.lib.optionalString withDinit ''
              install -Dm0644 resources/dinit/niri{,-shutdown} -t $out/lib/dinit.d/user
            ''
            + ''
              installShellCompletion --cmd niri \
                --bash <($out/bin/niri completions bash) \
                --zsh <($out/bin/niri completions zsh) \
                --fish <($out/bin/niri completions fish) \
                --nushell <($out/bin/niri completions nushell)

              install -Dm0644 README.md resources/default-config.kdl -t $doc/share/doc/niri
            '';

          meta = {
            description = "Scrollable-tiling Wayland compositor";
            homepage = "https://github.com/YaLTeR/niri";
            license = nixpkgs.lib.licenses.gpl3Only;
            maintainers = with nixpkgs.lib.maintainers; [ sodiboo ];
            mainProgram = "niri";
            platforms = nixpkgs.lib.platforms.linux;
          };
        };

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

      make-xwayland-satellite =
        {
          src,
          patches ? [ ],
          rustPlatform,
          pkg-config,
          makeWrapper,
          xwayland,
          xcb-util-cursor,
          withSystemd ? true,
        }:
        rustPlatform.buildRustPackage {
          pname = "xwayland-satellite";
          version = package-version src;
          inherit src patches;
          cargoLock = {
            lockFile = "${src}/Cargo.lock";
            allowBuiltinFetchGit = true;
          };
          nativeBuildInputs = [
            pkg-config
            rustPlatform.bindgenHook
            makeWrapper
          ];

          buildInputs = [
            xcb-util-cursor
          ];

          buildNoDefaultFeatures = true;
          buildFeatures = nixpkgs.lib.optional withSystemd "systemd";

          # All tests require a display server to be running.
          doCheck = false;

          # https://github.com/Supreeeme/xwayland-satellite/blob/388d291e82ffbc73be18169d39470f340707edaa/src/lib.rs#L51
          # https://github.com/rustyhorde/vergen/blob/9374f497395238b68ec4c6b43f69c4a78a111121/vergen-gitcl/src/lib.rs#L232
          VERGEN_GIT_DESCRIBE = version-string src;

          postInstall = ''
            wrapProgram $out/bin/xwayland-satellite \
              --prefix PATH : "${nixpkgs.lib.makeBinPath [ xwayland ]}"
          ''
          + nixpkgs.lib.optionalString withSystemd ''
            install -Dm0644 resources/xwayland-satellite.service -t $out/lib/systemd/user
          '';

          postFixup = nixpkgs.lib.optionalString withSystemd ''
            substituteInPlace $out/lib/systemd/user/xwayland-satellite.service \
              --replace-fail /usr/local/bin $out/bin
          '';

          meta = {
            description = "Rootless Xwayland integration to any Wayland compositor implementing xdg_wm_base";
            homepage = "https://github.com/Supreeeme/xwayland-satellite";
            license = nixpkgs.lib.licenses.mpl20;
            maintainers = with nixpkgs.lib.maintainers; [ sodiboo ];
            mainProgram = "xwayland-satellite";
            platforms = nixpkgs.lib.platforms.linux;
          };
        };

      make-package-set = pkgs: {
        niri = pkgs.callPackage make-niri {
          src = inputs.niri;
        };
        xwayland-satellite = pkgs.callPackage make-xwayland-satellite {
          src = inputs.xwayland-satellite;
        };
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
            nixpkgs.lib.mapAttrsToList (name: package: ''
              ln -s ${package} $out/${name}
            '') (combined-closure nixpkgs.legacyPackages.${system})
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
          default = self.apps.${system}.niri;
        }
      );

      formatter = forAllSystems (system: inputs.nixpkgs.legacyPackages.${system}.nixfmt-rfc-style);

      devShells = forAllSystems (system: {
        default = import ./shell.nix {
          flake = self;
          inherit system;
        };
      });

homeModules.config =
        {
          config,
          pkgs,
          lib,
          ...
        }:
        let
          cfg = config.programs.niri;
          kdl = import ./kdl.nix {
            inherit lib;
            inputs = inputs;
          };
        in
        {
          options.programs.niri = {
            package = nixpkgs.lib.mkOption {
              type = nixpkgs.lib.types.package;
              default = (make-package-set pkgs).niri;
              description = "The niri package to use.";
            };
            config = nixpkgs.lib.mkOption {
              type = nixpkgs.lib.types.nullOr (
                nixpkgs.lib.types.either nixpkgs.lib.types.str kdl.types.kdl-document
              );
              default = null;
              description = ''
                The niri config file.

                - When this is null, no config file is generated.
                - When this is a string, it is assumed to be the config file contents.
                - When this is a KDL document, it is serialized to a string before being used.
              '';
            };
          };

          config.xdg.configFile.niri-config = {
            enable = cfg.config != null;
            target = "niri/config.kdl";
            source =
              let
                final-config =
                  if builtins.isString cfg.config then
                    cfg.config
                  else if cfg.config != null then
                    kdl.serialize.nodes cfg.config
                  else
                    null;
              in
              validated-config-for pkgs cfg.package final-config;
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
              default = (make-package-set pkgs).niri;
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

          nixos = test-nixos-for nixpkgs [
            self.nixosModules.niri
            {
              programs.niri.enable = true;
            }
          ];
        }
      );
    };
}
