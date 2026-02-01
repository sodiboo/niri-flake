{
  version,
  versionString,
  src,
  patches ? [ ],
  cargoHash,
  lib,
  rustPlatform,
  pkg-config,
  installShellFiles,
  wayland,
  systemdLibs,
  eudev,
  pipewire,
  libgbm,
  libglvnd,
  seatd,
  libinput,
  libxkbcommon,
  libdisplay-info_0_2 ? libdisplay-info,
  libdisplay-info,
  pango,
  withDbus ? true,
  withDinit ? false,
  withScreencastSupport ? true,
  withSystemd ? true,

  # remove param at next release after 25.11 (yes! i know that's not even the stable version provided by this flake right now. i'm Working On It™)
  replace-service-with-usr-bin,
  ...
}:
assert libdisplay-info_0_2.version == "0.2.0";
rustPlatform.buildRustPackage {
  pname = "niri";
  inherit
    version
    src
    patches
    cargoHash
    ;
  nativeBuildInputs = [
    pkg-config
    rustPlatform.bindgenHook
    installShellFiles
  ];

  buildInputs = [
    wayland
    libgbm
    libglvnd
    seatd
    libinput
    libdisplay-info_0_2
    libxkbcommon
    pango
  ]
  ++ lib.optional withScreencastSupport pipewire
  ++ lib.optional withSystemd systemdLibs # we only need udev, really.
  ++ lib.optional (!withSystemd) eudev; # drop-in replacement for systemd-udev

  checkFlags = [
    # Some tests require surfaceless OpenGL displays. The "surfaceless" part means we don't need a Wayland or Xorg server;
    # but they still fundamentally require GPU drivers, which are only (sometimes) present at runtime.
    "--skip=::egl"
  ];

  buildNoDefaultFeatures = true;
  buildFeatures =
    lib.optional withDbus "dbus"
    ++ lib.optional withDinit "dinit"
    ++ lib.optional withScreencastSupport "xdp-gnome-screencast"
    ++ lib.optional withSystemd "systemd";

  passthru.providedSessions = [ "niri" ];

  # we want backtraces to be readable
  dontStrip = true;

  RUSTFLAGS = [
    "-C link-arg=-Wl,--push-state,--no-as-needed"
    "-C link-arg=-lEGL"
    "-C link-arg=-lwayland-client"
    "-C link-arg=-Wl,--pop-state"

    "-C debuginfo=line-tables-only"
  ];

  NIRI_BUILD_VERSION_STRING = versionString;

  outputs = [
    "out"
    "doc"
  ];

  # previously, the second line was part of RUSTFLAGS above
  # but i noticed it stopped working? because it doesn't interpolate the env var anymore.
  #
  # i don't know when or why it stopped working. but moving it here fixes it.
  # the first line was unnecessary previously because this should be the default
  # https://github.com/NixOS/nixpkgs/blob/11cf80ae321c35132c1aff950f026e9783f06fec/pkgs/build-support/rust/build-rust-crate/build-crate.nix#L19
  # but for some reason it isn't. so i'm doing it manually.
  #
  # the purpose is to make backtraces more readable. the first line strips the useless `/build` prefix
  # and the second line makes niri-related paths more obvious as if they were based on pwd with `cargo run`
  postPatch = ''
    export RUSTFLAGS="$RUSTFLAGS --remap-path-prefix $NIX_BUILD_TOP=/"
    export RUSTFLAGS="$RUSTFLAGS --remap-path-prefix $NIX_BUILD_TOP/source=./"

    patchShebangs resources/niri-session
  '';

  postInstall =
    # niri.desktop calls `niri-session` and that executable only works with systemd or dinit
    lib.optionalString (withSystemd || withDinit) ''
      install -Dm0755 resources/niri-session -t $out/bin
      install -Dm0644 resources/niri.desktop -t $out/share/wayland-sessions
    ''
    # any of these features will enable dbus support
    + lib.optionalString (withDbus || withScreencastSupport || withSystemd) ''
      install -Dm0644 resources/niri-portals.conf -t $out/share/xdg-desktop-portal
    ''
    + lib.optionalString withSystemd ''
      install -Dm0644 resources/niri{-shutdown.target,.service} -t $out/lib/systemd/user
    ''
    + lib.optionalString withDinit ''
      install -Dm0644 resources/dinit/niri{,-shutdown} -t $out/lib/dinit.d/user
    ''
    + ''
      installShellCompletion --cmd niri \
        --bash <($out/bin/niri completions bash) \
        --zsh <($out/bin/niri completions zsh) \
        --fish <($out/bin/niri completions fish) \
        --nushell <($out/bin/niri completions nushell)

      install -Dm0644 README.md resources/default-config.kdl -t $doc/share/doc/niri
      mv docs/wiki $doc/share/doc/niri/wiki
    '';

  postFixup =
    if replace-service-with-usr-bin then
      ''
        substituteInPlace $out/lib/systemd/user/niri.service --replace-fail /usr/bin $out/bin
      ''
    else
      ''
        substituteInPlace $out/lib/systemd/user/niri.service --replace-fail "ExecStart=niri" "ExecStart=$out/bin/niri"
      '';

  meta = {
    description = "Scrollable-tiling Wayland compositor";
    homepage = "https://github.com/YaLTeR/niri";
    license = lib.licenses.gpl3Only;
    maintainers = with lib.maintainers; [ sodiboo ];
    mainProgram = "niri";
    platforms = lib.platforms.linux;
  };
}
