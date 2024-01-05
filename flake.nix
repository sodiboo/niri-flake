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
      # TODO: generalize. this ought to have at least aarch64-linux but:
      # - it won't work as long as the other two TODOs are not addressed
      # - and it's not a priority to fix, because i cannot test anyways
      # even so, i'm using flake-parts for nearly system-agnostic flake
      # if you need on aarch64-linux now, just clone and s/x86_64/aarch64/
      systems = ["x86_64-linux"];
      perSystem = {
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

                  niri = attrs: {
                    buildInputs = [libxkbcommon libinput mesa libglvnd wayland];
                    # There is supposedly an extraLinkFlags attribute but it doesn't seem to work.
                    extraRustcOpts = [
                      "-Clink-arg=-Wl,--push-state,--no-as-needed"
                      "-Clink-arg=-lEGL"
                      "-Clink-arg=-lwayland-client"
                      "-Clink-arg=-Wl,--pop-state"
                    ];
                  };
                });
            };
        };

        niri-bin = workspace.rootCrate.build;

        bundled =
          pkgs.runCommand "niri" {
            passthru.providedSessions = ["niri"];
          } ''
            mkdir -p $out/bin
            mkdir -p $out/lib/systemd/user
            mkdir -p $out/share/wayland-sessions
            mkdir -p $out/share/xdg-desktop-portal

            cp ${niri-bin}/bin/niri $out/bin/niri
            cp ${niri-src}/resources/niri-session $out/bin/niri-session
            cp ${niri-src}/resources/niri.service $out/lib/systemd/user/niri.service
            cp ${niri-src}/resources/niri-shutdown.target $out/lib/systemd/user/niri-shutdown.target
            cp ${niri-src}/resources/niri.desktop $out/share/wayland-sessions
            cp ${niri-src}/resources/niri-portals.conf $out/share/xdg-desktop-portal/niri-portals.conf

            sed -i "s#/usr#$out#" $out/lib/systemd/user/niri.service
          '';
      in {
        packages = rec {
          niri = bundled;
          default = niri;
        };

        apps = rec {
          niri = {
            type = "app";
            program = "${bundled}/bin/niri";
          };
          default = niri;
        };

        formatter = pkgs.alejandra;
      };

      flake = {
        nixosModules = rec {
          niri = {
            lib,
            config,
            ...
          }: let
            # TODO: generalize. this system should be that of the target host
            # i.e. the one related to `config`
            packages = self.packages.x86_64-linux;
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
          default = niri;
        };

        validate-config = src: let
          # TODO: generalize. this system should be that of the build host
          # i.e. the one related to `import nixpkgs {}`
          packages = self.packages.x86_64-linux;
          pkgs = nixpkgs.legacyPackages.x86_64-linux;
          config = pkgs.writeText "config.kdl" src;
          validated =
            pkgs.runCommand "niri-validate" {
              buildInputs = [packages.niri];
            } ''
              niri validate -c ${config}
              mkdir $out
              ln -s ${config} $out/config.kdl
            '';
        in
          builtins.readFile "${validated}/config.kdl";
      };
    };
}
