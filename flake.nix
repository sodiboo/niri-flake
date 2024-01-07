{
  description = "A scrollable-tiling Wayland compositor.";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";

    crate2nix.url = "github:nix-community/crate2nix";

    niri-src.url = "github:YaLTeR/niri";
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

                  niri-config = attrs: {
                    prePatch = ''sed -i 's#\.\./\.\.#${niri-src}#' src/lib.rs'';
                  };

                  niri = attrs: {
                    buildInputs = [libxkbcommon libinput mesa libglvnd wayland];

                    # niri is alpha-quality software, and as such it is important for backtraces to be readable
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
            workspace.workspaceMembers.niri.build
            // {
              validate-config = src:
                builtins.readFile (pkgs.runCommand "config.kdl" {
                    config = src;
                    passAsFile = ["config"];
                    buildInputs = [self'.packages.niri];
                  } ''
                    niri validate -c $configPath
                    cp $configPath $out
                  '');
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

      flake.nixosModules.default = {
        lib,
        config,
        pkgs,
        ...
      }: let
        packages = self.packages.${pkgs.stdenv.system};
        cfg = config.programs.niri;
      in
        with lib; {
          options.programs.niri = {
            enable = mkEnableOption "niri";
          };

          config = mkIf cfg.enable {
            environment.systemPackages = [packages.niri];
            services.xserver.displayManager.sessionPackages = [packages.niri];
            systemd.user.units = builtins.listToAttrs (builtins.map (unit: {
              name = unit;
              value.text = builtins.readFile "${packages.niri}/lib/systemd/user/${unit}";
            }) ["niri.service" "niri-shutdown.target"]);
          };
        };
    };
}
