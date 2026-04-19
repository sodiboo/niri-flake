{
  version,
  versionString,
  src,
  patches ? [ ],
  cargoHash,
  lib,
  rustPlatform,
  pkg-config,
  makeWrapper,
  xwayland,
  xcb-util-cursor,
  withSystemd ? true,
  ...
}:
rustPlatform.buildRustPackage {
  pname = "xwayland-satellite";
  inherit
    version
    src
    patches
    cargoHash
    ;
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
  VERGEN_GIT_DESCRIBE = versionString;

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
