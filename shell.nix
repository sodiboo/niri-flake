{
  flake ? builtins.getFlake (toString ./.),
  system ? builtins.currentSystem,
}:
let
  pkgs = flake.inputs.nixpkgs.legacyPackages.${system};
in
pkgs.mkShell {
  packages = with pkgs; [
    flake.formatter.${system}
    just
    fish
    fd
    entr
    moreutils
  ];

  shellHook = ''
    just hook 2>/dev/null
  '';
}
