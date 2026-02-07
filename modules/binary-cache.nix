{ lib, config, ... }:
{
  options.niri-flake.cache.enable = lib.mkEnableOption "the niri-flake binary cache" // {
    default = true;
  };

  config = lib.mkIf config.niri-flake.cache.enable {
    nix.settings = {
      substituters = [ "https://niri.cachix.org" ];
      trusted-public-keys = [ "niri.cachix.org-1:Wv0OmO7PsuocRKzfDoJ3mulSl7Z6oezYhGhR+3W2964=" ];
    };
  };
}
