{
  inputs,
}:
{
  config,
  options,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.programs.niri;
  packageSet = import ./package.nix {
    inherit inputs;
  };
in
{
  # The module from this flake predates the module in nixpkgs by a long shot.
  # To avoid conflicts, we disable the nixpkgs module.
  # Eventually, this module (e.g. `niri.nixosModules.niri`) will be deprecated
  # in favour of other modules that aren't redundant with nixpkgs (and don't yet exist)
  disabledModules = [ "programs/wayland/niri.nix" ];

  options.programs.niri = {
    enable = lib.mkEnableOption "niri";
    package = lib.mkOption {
      type = lib.types.package;
      default = (packageSet pkgs).niri-stable;
      description = "The niri package to use.";
    };
  };

  options.niri-flake.cache.enable = lib.mkEnableOption "the niri-flake binary cache" // {
    default = true;
  };

  config = lib.mkMerge [
    (lib.mkIf config.niri-flake.cache.enable {
      nix.settings = {
        substituters = [ "https://niri.cachix.org" ];
        trusted-public-keys = [ "niri.cachix.org-1:Wv0OmO7PsuocRKzfDoJ3mulSl7Z6oezYhGhR+3W2964=" ];
      };
    })
    (lib.mkIf cfg.enable {
      environment.systemPackages = [
        pkgs.xdg-utils
        cfg.package
      ];
      xdg = {
        autostart.enable = lib.mkDefault true;
        menus.enable = lib.mkDefault true;
        mime.enable = lib.mkDefault true;
        icons.enable = lib.mkDefault true;
      };

      services.displayManager.sessionPackages = [ cfg.package ];
      hardware.graphics.enable = lib.mkDefault true;

      xdg.portal = {
        enable = true;
        extraPortals = lib.mkIf (
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
      programs.dconf.enable = lib.mkDefault true;
      fonts.enableDefaultPackages = lib.mkDefault true;
    })
    (lib.optionalAttrs (options ? home-manager) {
      home-manager.sharedModules = [
        (import ./home-module-config.nix)
        { programs.niri.package = lib.mkForce cfg.package; }
      ]
      ++ lib.optionals (options ? stylix) [ (import ./stylix.nix) ];
    })
  ];
}
