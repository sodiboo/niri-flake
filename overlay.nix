finalAttrs: prevAttrs:
let
  nirilib = prevAttrs.callPackage ./lib.nix {
    inherit (finalAttrs) lib pkgs;
    inputs = finalAttrs.inputs ? null;
  };

  flakeLock = prevAttrs.lib.importJSON ./flake.lock;
in
{
  niri-stable = finalAttrs.callPackage nirilib.make-niri {
    src = prevAttrs.fetchFromGitHub {
      inherit (flakeLock.nodes.niri-stable.locked) owner repo rev;
      hash = flakeLock.nodes.niri-stable.locked.narHash;
      passthru = {
        lastModifiedDate = nirilib.formatSecondsSinceEpoch flakeLock.nodes.niri-stable.locked.lastModified;
        shortRev = prevAttrs.lib.sources.shortRev flakeLock.nodes.niri-stable.locked.rev;
      };
    };
    replace-service-with-usr-bin = true;
  };
  niri-unstable = finalAttrs.callPackage nirilib.make-niri {
    src = prevAttrs.fetchFromGitHub {
      inherit (flakeLock.nodes.niri-unstable.locked) owner repo rev;
      hash = flakeLock.nodes.niri-unstable.locked.narHash;
      passthru = {
        lastModifiedDate = nirilib.formatSecondsSinceEpoch flakeLock.nodes.niri-unstable.locked.lastModified;
        shortRev = prevAttrs.lib.sources.shortRev flakeLock.nodes.niri-unstable.locked.rev;
      };
    };
    replace-service-with-usr-bin = false;
  };
  xwayland-satellite-stable = finalAttrs.callPackage nirilib.make-xwayland-satellite {
    src = prevAttrs.fetchFromGitHub {
      inherit (flakeLock.nodes.xwayland-satellite-stable.locked) owner repo rev;
      hash = flakeLock.nodes.xwayland-satellite-stable.locked.narHash;
      passthru = {
        lastModifiedDate = nirilib.formatSecondsSinceEpoch flakeLock.nodes.xwayland-satellite-stable.locked.lastModified;
        shortRev = prevAttrs.lib.sources.shortRev flakeLock.nodes.xwayland-satellite-stable.locked.rev;
      };
    };
  };
  xwayland-satellite-unstable = finalAttrs.callPackage nirilib.make-xwayland-satellite {
    src = prevAttrs.fetchFromGitHub {
      inherit (flakeLock.nodes.xwayland-satellite-unstable.locked) owner repo rev;
      hash = flakeLock.nodes.xwayland-satellite-unstable.locked.narHash;
      passthru = {
        lastModifiedDate = nirilib.formatSecondsSinceEpoch flakeLock.nodes.xwayland-satellite-unstable.locked.lastModified;
        shortRev = prevAttrs.lib.sources.shortRev flakeLock.nodes.xwayland-satellite-unstable.locked.rev;
      };
    };
  };
}
