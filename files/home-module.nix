{
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.programs.niri;
in
{
  imports = [
    ./home-module-config.nix
  ];
  options.programs.niri = {
    enable = lib.mkEnableOption "niri";
  };

  config = lib.mkIf cfg.enable {
    home.packages = [ cfg.package ];
    services.gnome-keyring.enable = true;
    xdg.portal = {
      enable = true;
      extraPortals = lib.mkIf (
        !cfg.package.cargoBuildNoDefaultFeatures
        || builtins.elem "xdp-gnome-screencast" cfg.package.cargoBuildFeatures
      ) [ pkgs.xdg-desktop-portal-gnome ];
      configPackages = [ cfg.package ];
    };
  };
}
