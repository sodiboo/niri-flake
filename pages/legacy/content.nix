{
  inputs,
  lib,
  kdl,
  fmt,
  fmt-date,
  fmt-time,
}:
{
  imports = [ (import ../../settings.nix { inherit lib kdl fmt; }) ];

  options._ =
    let
      section =
        contents:
        lib.mkOption {
          type = lib.mkOptionType { name = "docs-override"; };
          description = contents;
        };

      header = title: section "# ${title}";
      fake-option =
        loc: contents:
        section ''
          ## `${loc}`

          ${contents}
        '';

      module-doc =
        name: desc: opts:
        {
          _ = section ''
            # `${name}`

            ${desc}
          '';
        }
        // opts;

      pkg-header = name: "packages.<system>.${name}";
      pkg-link = name: "[`pkgs.${name}`](#${fmt.markdown-anchor (pkg-header name)})";

      nixpkgs-link =
        name: "[`pkgs.${name}`](https://search.nixos.org/packages?channel=unstable&show=${name})";

      pkg-output =
        name: desc:
        fake-option (pkg-header name) ''
          ${desc}

          To access this package under `pkgs.${name}`, you should use ${
            fmt.link' [
              "overlays"
              "niri"
            ]
          }.
        '';

      enable-option = fake-option "programs.niri.enable" ''
        - type: `boolean`
        - default: `false`

        Whether to install and enable niri.

        This also enables the necessary system components for niri to function properly, such as desktop portals and polkit.
      '';

      package-option = fake-option "programs.niri.package" ''
        - type: `package`
        - default: ${pkg-link "niri-stable"}

        The package that niri will use.

        You may wish to set it to the following values:

        - ${nixpkgs-link "niri"}
        - ${pkg-link "niri-stable"}
        - ${pkg-link "niri-unstable"}
      '';

      patches =
        pkg:
        builtins.concatMap (
          patch:
          let
            m = lib.strings.match "${lib.escapeRegex "https://github.com/YaLTeR/niri/commit/"}([0-9a-f]{40})${lib.escapeRegex ".patch"}" patch.url;
          in
          if m != null then
            [
              {
                rev = builtins.head m;
                inherit (patch) url;
              }
            ]
          else
            [ ]
        ) (pkg.patches or [ ]);

      stable-patches = patches inputs.self.packages.x86_64-linux.niri-stable;
    in
    {
      a.nonmodules = {
        _ = header "Packages provided by this flake";

        a.packages = {
          _ = fake-option (pkg-header "<name>") ''
            (where `<system>` is one of: `x86_64-linux`, `aarch64-linux`)

            > [!important]
            > Packages for `aarch64-linux` are untested. They might work, but i can't guarantee it.

            You should preferably not be using these outputs directly. Instead, you should use ${
              fmt.link' [
                "overlays"
                "niri"
              ]
            }.
          '';
          niri-stable = pkg-output "niri-stable" ''
            The latest stable tagged version of niri, along with potential patches.

            Currently, this is release ${fmt.link-niri-release inputs.self.packages.x86_64-linux.niri-stable.version}${
              if stable-patches != [ ] then " plus the following patches:" else " with no additional patches."
            }

            ${builtins.concatStringsSep "\n" (
              map (
                {
                  rev,
                  url,
                }:
                "- [`${rev}`](${lib.removeSuffix ".patch" url})"
              ) stable-patches
            )}
          '';
          niri-unstable = pkg-output "niri-unstable" ''
            The latest commit to the development branch of niri.

            Currently, this is exactly commit ${
              fmt.link-niri-commit { inherit (inputs.niri-unstable) shortRev rev; }
            } which was authored on `${fmt-date inputs.niri-unstable.lastModifiedDate} ${fmt-time inputs.niri-unstable.lastModifiedDate}`.

            > [!warning]
            > `niri-unstable` is not a released version, there are no stability guarantees, and it may break your workflow from itme to time.
            >
            > The specific package provided by this flake is automatically updated without any testing. The only guarantee is that it builds.
          '';
        };

        b.overlay = fake-option "overlays.niri" ''
          A nixpkgs overlay that provides `niri-stable` and `niri-unstable`.

          It is recommended to use this overlay over directly accessing the outputs. This is because the overlay ensures that the dependencies match your system's nixpkgs version, which is most important for `mesa`. If `mesa` doesn't match, niri will be unable to run in a TTY.

          You can enable this overlay by adding this line to your configuration:

          ```nix
          {
            nixpkgs.overlays = [ niri.overlays.niri ];
          }
          ```

          You can then access the packages via `pkgs.niri-stable` and `pkgs.niri-unstable` as if they were part of nixpkgs.
        '';
      };
      b.modules = {
        a.nixos =
          module-doc "nixosModules.niri"
            ''
              The full NixOS module for niri.

              By default, this module does the following:

              - It will enable a binary cache managed by me, sodiboo. This helps you avoid building niri from source, which can take a long time in release mode.
              - If you have home-manager installed in your NixOS configuration (rather than as a standalone program), this module will automatically import ${
                fmt.link' [
                  "homeModules"
                  "config"
                ]
              } for all users and give it the correct package to use for validation.
              - If you have home-manager and stylix installed in your NixOS configuration, this module will also automatically import ${
                fmt.link' [
                  "homeModules"
                  "stylix"
                ]
              } for all users.
            ''
            {
              enable = enable-option;
              package = package-option;
              z.cache = fake-option "niri-flake.cache.enable" ''
                - type: `boolean`
                - default: `true`

                Whether or not to enable the binary cache [`niri.cachix.org`](https://niri.cachix.org/) in your nix configuration.

                Using a binary cache can save you time, by avoiding redundant rebuilds.

                This cache is managed by me, sodiboo, and i use GitHub Actions to automaticaly upload builds of ${pkg-link "niri-stable"} and ${pkg-link "niri-unstable"} (for nixpkgs unstable and stable). By using it, you are trusting me to not upload malicious builds, and as such you may disable it.

                If you do not wish to use this cache, then you may wish to set ${
                  fmt.link' [
                    "programs"
                    "niri"
                    "package"
                  ]
                } to ${nixpkgs-link "niri"}, in order to take advantage of the NixOS cache.
              '';
            };

        b.home =
          module-doc "homeModules.niri"
            ''
              The full home-manager module for niri.

              By default, this module does nothing. It will import ${
                fmt.link' [
                  "homeModules"
                  "config"
                ]
              }, which provides many configuration options, and it also provides some options to install niri.
            ''
            {
              enable = enable-option;
              package = package-option;
            };

        c.stylix =
          module-doc "homeModules.stylix"
            ''
              Stylix integration. It provides a target to enable niri.

              This module is automatically imported if you have home-manager and stylix installed in your NixOS configuration.

              If you use standalone home-manager, you must import it manually if you wish to use stylix with niri. (since it can't be automatically imported in that case)
            ''
            {
              target = fake-option "stylix.targets.niri.enable" ''
                - type: `boolean`
                - default: ${fmt.link-stylix-opt "stylix.autoEnable"}

                Whether to style niri according to your stylix config.

                Note that enabling this stylix target will cause a config file to be generated, even if you don't set ${
                  fmt.link' [
                    "programs"
                    "niri"
                    "config"
                  ]
                }.

                This also means that, with stylix installed, having everything set to default *does* generate an actual config file.
              '';
            };
      };

      z.pre-config =
        module-doc "homeModules.config"
          ''
            Configuration options for niri. This module is automatically imported by ${
              fmt.link' [
                "nixosModules"
                "niri"
              ]
            } and ${
              fmt.link' [
                "homeModules"
                "niri"
              ]
            }.

            By default, this module does nothing. It provides many configuration options for niri, such as keybindings, animations, and window rules.

            When its options are set, it generates `$XDG_CONFIG_HOME/niri/config.kdl` for the user. This is the default path for niri's config file.

            It will also validate the config file with the `niri validate` command before committing that config. This ensures that the config file is always valid, else your system will fail to build. When using ${
              fmt.link' [
                "programs"
                "niri"
                "settings"
              ]
            } to configure niri, that's not necessary, because it will always generate a valid config file. But, if you set ${
              fmt.link' [
                "programs"
                "niri"
                "config"
              ]
            } directly, then this is very useful.
          ''
          {
            a.variant = section ''
              ## type: `variant of`

              Some of the options below make use of a "variant" type.

              This is a type that behaves similarly to a submodule, except you can only set *one* of its suboptions.

              An example of this usage is in ${
                fmt.link' [
                  "programs"
                  "niri"
                  "settings"
                  "animations"
                  "<name>"
                ]
              }, where each event can have either an easing animation or a spring animation. \
              You cannot set parameters for both, so `variant` is used here.
            '';

            b.package = fake-option "programs.niri.package" ''
              - type: `package`
              - default: ${pkg-link "niri-stable"}

              The `niri` package that the config is validated against. This cannot be modified if you set the identically-named option in ${
                fmt.link' [
                  "nixosModules"
                  "niri"
                ]
              } or ${
                fmt.link' [
                  "homeModules"
                  "niri"
                ]
              }.
            '';
          };
    };
}
