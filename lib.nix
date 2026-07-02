{
  lib,
  pkgs,
  inputs ? { },
}:

let

  stable-revs = import ./refs.nix;

  date = {
    year = builtins.substring 0 4;
    month = builtins.substring 4 2;
    day = builtins.substring 6 2;
    hour = builtins.substring 8 2;
    minute = builtins.substring 10 2;
    second = builtins.substring 12 2;
  };

  fmt-date = raw: "${date.year raw}-${date.month raw}-${date.day raw}";
  fmt-time = raw: "${date.hour raw}:${date.minute raw}:${date.second raw}";

  version-string =
    src:
    if stable-revs ? ${src.rev} then
      "stable ${stable-revs.${src.rev}} (commit ${src.rev})"
    else
      "unstable ${fmt-date src.lastModifiedDate} (commit ${src.rev})";

  package-version =
    src:
    if stable-revs ? ${src.rev} then
      lib.removePrefix "v" stable-revs.${src.rev}
    else
      "unstable-${fmt-date src.lastModifiedDate}-${src.shortRev}";
in
rec {
  # From https://github.com/NixOS/flake-compat/blob/5edf11c44bc78a0d334f6334cdaf7d60d732daab/default.nix#L173-L197
  formatSecondsSinceEpoch =
    t:
    let
      rem = x: y: x - x / y * y;
      days = t / 86400;
      secondsInDay = rem t 86400;
      hours = secondsInDay / 3600;
      minutes = (rem secondsInDay 3600) / 60;
      seconds = rem t 60;

      # Courtesy of https://stackoverflow.com/a/32158604.
      z = days + 719468;
      era = (if z >= 0 then z else z - 146096) / 146097;
      doe = z - era * 146097;
      yoe = (doe - doe / 1460 + doe / 36524 - doe / 146096) / 365;
      y = yoe + era * 400;
      doy = doe - (365 * yoe + yoe / 4 - yoe / 100);
      mp = (5 * doy + 2) / 153;
      d = doy - (153 * mp + 2) / 5 + 1;
      m = mp + (if mp < 10 then 3 else -9);
      y' = y + (if m <= 2 then 1 else 0);

      pad = s: if builtins.stringLength s < 2 then "0" + s else s;
    in
    "${toString y'}${pad (toString m)}${pad (toString d)}${pad (toString hours)}${pad (toString minutes)}${pad (toString seconds)}";

  make-niri =
    {
      lib,
      src,
      patches ? [ ],
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
    }:
    assert libdisplay-info_0_2.version == "0.2.0";
    rustPlatform.buildRustPackage {
      pname = "niri";
      version = package-version src;
      src = src;
      inherit patches;
      cargoLock = {
        lockFile = "${src}/Cargo.lock";
        allowBuiltinFetchGit = true;
      };
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

      NIRI_BUILD_VERSION_STRING = version-string src;

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
    };

  make-xwayland-satellite =
    {
      lib,
      src,
      patches ? [ ],
      rustPlatform,
      pkg-config,
      makeWrapper,
      xwayland,
      xcb-util-cursor,
      withSystemd ? true,
    }:
    rustPlatform.buildRustPackage {
      pname = "xwayland-satellite";
      version = package-version src;
      inherit src patches;
      cargoLock = {
        lockFile = "${src}/Cargo.lock";
        allowBuiltinFetchGit = true;
      };
      nativeBuildInputs = [
        pkg-config
        rustPlatform.bindgenHook
        makeWrapper
      ];

      buildInputs = [
        xcb-util-cursor
      ];

      buildNoDefaultFeatures = true;
      buildFeatures = lib.optional withSystemd "systemd";

      # All tests require a display server to be running.
      doCheck = false;

      # https://github.com/Supreeeme/xwayland-satellite/blob/388d291e82ffbc73be18169d39470f340707edaa/src/lib.rs#L51
      # https://github.com/rustyhorde/vergen/blob/9374f497395238b68ec4c6b43f69c4a78a111121/vergen-gitcl/src/lib.rs#L232
      VERGEN_GIT_DESCRIBE = version-string src;

      postInstall = ''
        wrapProgram $out/bin/xwayland-satellite \
          --prefix PATH : "${lib.makeBinPath [ xwayland ]}"
      ''
      + lib.optionalString withSystemd ''
        install -Dm0644 resources/xwayland-satellite.service -t $out/lib/systemd/user
      '';

      postFixup = lib.optionalString withSystemd ''
        substituteInPlace $out/lib/systemd/user/xwayland-satellite.service \
          --replace-fail /usr/local/bin $out/bin
      '';

      meta = {
        description = "Rootless Xwayland integration to any Wayland compositor implementing xdg_wm_base";
        homepage = "https://github.com/Supreeeme/xwayland-satellite";
        license = lib.licenses.mpl20;
        maintainers = with lib.maintainers; [ sodiboo ];
        mainProgram = "xwayland-satellite";
        platforms = lib.platforms.linux;
      };
    };

  validated-config-for =
    pkgs: package: config:
    pkgs.runCommand "config.kdl"
      {
        inherit config;
        passAsFile = [ "config" ];
        buildInputs = [ package ];
      }
      ''
        niri validate -c $configPath
        cp $configPath $out
      '';
  make-package-set = pkgs: (import ./overlay.nix) (pkgs // { inherit inputs; }) pkgs;
  kdl = import ./kdl.nix { inherit lib; };
  binds = import ./parse-binds.nix { inherit lib; };
  docs = import ./generate-docs.nix { inherit lib inputs; };
  html-docs = import ./generate-html-docs.nix { inherit lib; };
  settings = import ./settings.nix {
    inherit
      kdl
      lib
      docs
      binds
      settings
      pkgs
      ;
  };
}
