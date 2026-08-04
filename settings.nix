{
  lib,
  kdl,
  fmt,
  ...
}:
{
  config,
  options,
  pkgs,
  ...
}:
let
  cfg = config.programs.niri;

  inherit (lib) mkOption types;
in
{
  options.programs.niri = {
    settings = mkOption {
      type = types.nullOr (
        lib.types.submoduleWith {
          modules = [ ./settings/toplevel.nix ];
          specialArgs = {
            inherit kdl;
            niri-flake-internal-fmt = fmt;
          };
        }
      );
      default = null;
      description = ''
        Nix-native settings for niri.

        By default, when this is null, no config file is generated.

        Beware that setting ${fmt.link-opt options.programs.niri.config} completely overrides everything under this option.
      '';
    };

    config = mkOption {
      type = types.nullOr (types.either types.str kdl.types.kdl-document);
      default = if cfg.settings == null then null else cfg.settings.rendered;
      defaultText = null;
      description = ''
        The niri config file.

        - When this is null, no config file is generated.
        - When this is a string, it is assumed to be the config file contents.
        - When this is kdl document, it is serialized to a string before being used as the config file contents.

        By default, this is a KDL document that reflects the settings in ${fmt.link-opt options.programs.niri.settings}.
      '';
    };

    finalConfig = mkOption {
      type = types.nullOr types.str;
      default =
        if builtins.isString cfg.config then
          cfg.config
        else if cfg.config != null then
          if config._module.args ? pkgs then
            builtins.readFile (
              pkgs.callPackage kdl.generator {
                document = cfg.config;
              }
            )
          else
            ''
              invalid // mock instantiation of this module. unable to generate configuration.
            ''
        else
          null;
      readOnly = true;
      defaultText = null;
      description = ''
        The final niri config file contents.

        This is a string that reflects the document stored in ${fmt.link-opt options.programs.niri.config}.

        It is exposed mainly for debugging purposes, such as when you need to inspect how a certain option affects the resulting config file.
      '';
    };
  };
}
