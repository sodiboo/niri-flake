let
  set-user-module-location =
    {
      lib,
      args,
      attr,
    }:
    let
      default-file = (builtins.unsafeGetAttrPos attr args).file or null;
    in
    if default-file != null then lib.setDefaultModuleLocation default-file else lib.id;
in
{
  eval-settings =
    {
      lib,
      pkgs ? null,
      settings,
      specialArgs ? { },

      kdl ? import ../kdl.nix { inherit lib; },
      niri-flake-internal-fmt ? (import ./fmt { inherit lib; }).gfm.fmt,
    }@args:
    lib.evalModules {
      class = "niri-flake-settings";

      specialArgs = {
        inherit kdl niri-flake-internal-fmt;
      }
      // lib.optionalAttrs (args ? pkgs) { inherit pkgs; }
      // specialArgs;

      modules = [
        ./toplevel.nix
      ]
      ++ lib.optionals (settings != null) [
        (set-user-module-location {
          inherit lib args;
          attr = "settings";
        } settings)
      ];
    };

  make-type =
    {
      lib,
      pkgs ? null,
      modules ? [ ],
      specialArgs ? { },

      shorthandOnlyDefinesConfig ? true,

      kdl ? import ../kdl.nix { inherit lib; },
      niri-flake-internal-fmt ? (import ./fmt { inherit lib; }).gfm.fmt,
    }@args:
    lib.types.submoduleWith {
      class = "niri-flake-settings";
      description = "niri-flake settings";
      inherit shorthandOnlyDefinesConfig;

      specialArgs = {
        inherit kdl niri-flake-internal-fmt;
      }
      // lib.optionalAttrs (args ? pkgs) { inherit pkgs; }
      // specialArgs;

      modules = [
        ./toplevel.nix
      ]
      ++ lib.optionals (modules != [ ]) [
        (set-user-module-location {
          inherit lib args;
          attr = "modules";
        } { imports = modules; })
      ];
    };
}
