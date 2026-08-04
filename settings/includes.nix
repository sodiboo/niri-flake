{
  lib,
  kdl,
  niri-flake-utils,
  niri-flake-internal,
  toplevel-options,
  ...
}:
let

  inherit (niri-flake-internal)
    fmt
    ;

  inherit (niri-flake-utils) partitioned-list-of;
in
{
  options.includes = lib.mkOption {
    description = ''
      Includes for this config file.

      Notice that the type is a ${fmt.em "paritioned list"}. This option partitions its values based on if they are after the default order priority or not.

      ${fmt.nix-code-block ''
        {
          # Include the system-wide configuration for niri at the top.
          ${toplevel-options.includes} = [
            { path = "/etc/niri/config.kdl"; }
          ];
        }
      ''}

      All definitions in the Nixpkgs module system have an inherent "order priority" to them.
      This priority can be manually set using utilities like ${fmt.code "lib.mkOrder"}, ${fmt.code "lib.mkBefore"}, and ${fmt.code "lib.mkAfter"}:

      ${fmt.nix-code-block ''
        {
          # Include a file that is generated at runtime at the bottom.
          ${toplevel-options.includes} = lib.mkAfter [
            { path = "generated.kdl"; }
          ];
        }
      ''}

      Note that relative paths (like in the previous example) are resolved without dereferencing symlinks. As such, if this config file is symlinked to ${fmt.code "/home/sodiboo/.config/niri/config.kdl"}, and ${fmt.code "sodiboo"} runs niri normally, niri will look for that included file at ${fmt.code "/home/sodiboo/.config/niri/generated.kdl"}. It does not matter if the main config file actually lives in the Nix store, or anywhere else.

      You can configure whether each include is required or not. By default, includes are not required unless they are a Nix store path, but you can override this behaviour by specifying it manually:

      ${fmt.nix-code-block ''
        {
          # The system-wide niri configuration **must** exist, or else this config file will not load.
          # This can no longer be validated at system build time, because that path doesn't exist in the Nix sandbox.
          ${toplevel-options.includes} = [
            { required = true; path = "/etc/niri/config.kdl"; }
          ];
        }
      ''}

      If you just specify the path, you don't need to wrap it in an attrset:

      ${fmt.nix-code-block ''
        {
          # This includes the same file twice, both times optional.
          ${toplevel-options.includes} = [
            "shell/colors.kdl"
            { path = "shell/colors.kdl"; }
          ];
        }
      ''}

      If you want to specify includes for the start and end of the config file in the same location, you must use ${fmt.code "lib.mkMerge"}:

      ${fmt.nix-code-block ''
        {
          ${toplevel-options.includes} = lib.mkMerge [
            (lib.mkBefore [
              { required = true; path = "/etc/niri/config.kdl"; }
              "shell/base.kdl"
            ])
            (lib.mkAfter [
              "shell/overlay.kdl"
            ])
          ];
        }
      ''}

      That's because you can only set the priority on a given definition, not on individual entries:

      ${fmt.nix-code-block ''
        {
          # WRONG: lib.mkAfter must wrap the whole list, not individual values within it.
          ${toplevel-options.includes} = [
            (lib.mkAfter "invalid.kdl")
          ];
        }
      ''}

      Unlike some other parts of niri's configuration, there is no shorthand for the home directory:

      ${fmt.nix-code-block ''
        {
          # WRONG: The tilde is not expanded how you'd expect.
          ${toplevel-options.includes} = [
            { path = "~/.config/niri/generated.kdl"; }
          ];
        }
      ''}
    '';
    default = [ ];
    type = partitioned-list-of (
      lib.types.coercedTo (lib.types.pathWith { }) (path: { inherit path; }) (
        lib.types.submoduleWith {
          description = "config include";
          shorthandOnlyDefinesConfig = true;
          modules = [
            (
              { config, options, ... }:
              {
                options = {
                  path = lib.mkOption {
                    type = lib.types.pathWith { };
                    description = ''
                      The path to the file that is to be included. It can be relative to the current file, or an absolute path. Unlike some other paths in the niri configuration, it may ${fmt.em "not"} contain a tilde expansion at the start.
                    '';
                  };
                  required = lib.mkOption {
                    type = lib.types.bool;
                    default = lib.isStorePath config.path;
                    defaultText = "path is a store path";

                    description = ''
                      Whether this path must exist and contain a valid niri config file when the current config is loaded.

                      By default, all includes are optional unless the path is a store path. This is because it is generally expected to run ${fmt.code "niri validate"} at system build time, at which point the Nix store is all that exists.
                    '';
                  };

                  rendered = lib.mkOption {
                    type = kdl.types.kdl-node;
                    readOnly = true;
                    internal = true;
                    visible = false;
                  };
                };

                config.rendered = kdl.leaf "include" (
                  (lib.optional (!config.required) { optional = true; }) ++ [ config.path ]
                );
              }
            )
          ];
        }
      )
    );
  };

  # Actually rendered in `./toplevel.nix`, because it needs to be inserted both before and after the rest of the config.
  render = _: [ ];
}
