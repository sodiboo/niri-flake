{ inputs, ... }:
pkgs: {
  niri-stable = pkgs.callPackage ./niri.nix {
    src = inputs.niri-stable;
  };
  niri-unstable = pkgs.callPackage ./niri.nix {
    src = inputs.niri-unstable;
  };
  xwayland-satellite-stable = pkgs.callPackage ./xwayland-satellite.nix {
    src = inputs.xwayland-satellite-stable;
  };
  xwayland-satellite-unstable = pkgs.callPackage ./xwayland-satellite.nix {
    src = inputs.xwayland-satellite-unstable;
  };
}
