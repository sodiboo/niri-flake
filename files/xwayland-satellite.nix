{
  src,
  lib,
  patches ? [ ],
  rustPlatform,
  pkg-config,
  makeWrapper,
  xwayland,
  xcb-util-cursor,
  withSystemd ? true,
}:
let
  stable-revs = import ../refs.nix;

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
}
