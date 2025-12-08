{
  lib,
  kdl,
  niri-flake-internal,
  toplevel-options,
}:
let
  inherit (niri-flake-internal)
    fmt
    attrs
    link-opt
    subopts
    ;
in
{
  sections = [
    {
      options.debug = attrs kdl.types.kdl-args // {
        description = ''
          Debug options for niri.

          ${fmt.code "kdl arguments"} in the type refers to a list of arguments passed to a node under the ${fmt.code "debug"} section. This is a way to pass arbitrary KDL-valid data to niri. See ${link-opt (subopts toplevel-options.binds).action} for more information on all the ways you can use this.

          Note that for no-argument nodes, there is no special way to define them here. You can't pass them as just a "string" because that makes no sense here. You must pass it an empty array of arguments.

          Here's an example of how to use this:

          ${fmt.nix-code-block ''
            {
              ${toplevel-options.debug} = {
                disable-cursor-plane = [];
                render-drm-device = "/dev/dri/renderD129";
              };
            }
          ''}

          This option is, just like ${link-opt (subopts toplevel-options.binds).action}, not verified by the nix module. But, it will be validated by niri before committing the config.

          Additionally, i don't guarantee stability of the debug options. They may change at any time without prior notice, either because of niri changing the available options, or because of me changing this to a more reasonable schema.
        '';
      };
    }
  ];
}
