# fifine Control Deck for Linux (https://github.com/ZoutMax/FifineControlDeck):
# PyQt6 app driving the fifine / Mirabox Stream Dock 293V3 (USB 3142:0060).
#
# Not a setuptools project, so the tree goes in $out/share like the upstream
# .deb (/usr/lib/fifine-control-deck) and a wrapper runs `python -m fifine_deck`.
# USB I/O goes through Mirabox's prebuilt libtransport.so (MIT, loaded with
# ctypes from its own directory); autoPatchelf points it at systemd's libudev
# and the C++ runtime. The Windows/macOS/arm64 builds are dropped.
{
  lib,
  stdenv,
  python3,
  qt6,
  autoPatchelfHook,
  makeWrapper,
  systemdLibs,
  # Tools the built-in actions shell out to (media, volume, open URL, hotkeys).
  playerctl,
  wireplumber,
  pulseaudio,
  xdg-utils,
  wtype,
  libnotify,
}:
let
  python = python3.withPackages (ps: [
    ps.pyqt6
    ps.pillow
    ps.psutil
    ps.pyudev # netlink hotplug instead of polling
    ps.keyring # secret store for password actions
  ]);
in
stdenv.mkDerivation {
  pname = "fifine-control-deck";
  version = "0.12.9"; # bump with the upstream release tag

  # fileset, not cleanSource: cleanSource drops *.so, i.e. libtransport.so.
  src = lib.fileset.toSource {
    root = ../.;
    fileset = lib.fileset.unions [
      ../fifine_deck
      ../assets
      ../probe_device.py
      ../packaging/fifine-control-deck.desktop
    ];
  };

  nativeBuildInputs = [ autoPatchelfHook makeWrapper qt6.wrapQtAppsHook ];
  buildInputs = [ systemdLibs stdenv.cc.cc.lib qt6.qtbase qt6.qtwayland ];

  dontBuild = true;
  dontWrapQtApps = true; # wrapped by hand below, the entry point is python

  installPhase = ''
    runHook preInstall

    share=$out/share/fifine-control-deck
    mkdir -p $share
    cp -r fifine_deck assets probe_device.py $share/

    dll=$share/fifine_deck/backend/StreamDock/Transport/TransportDLL
    find $dll -type f ! -name libtransport.so -delete
    rm -f $share/fifine_deck/backend/StreamDock/Transport/test.py

    install -Dm644 assets/app/fifine-deck-256.png \
      $out/share/icons/hicolor/256x256/apps/fifine-control-deck.png
    install -Dm644 packaging/fifine-control-deck.desktop \
      $out/share/applications/fifine-control-deck.desktop

    runHook postInstall
  '';

  postFixup = ''
    share=$out/share/fifine-control-deck
    makeWrapperArgs+=(
      --prefix PYTHONPATH : $share
      --prefix PATH : ${lib.makeBinPath [ playerctl wireplumber pulseaudio xdg-utils wtype libnotify ]}
      "''${qtWrapperArgs[@]}"
    )
    makeWrapper ${python}/bin/python3 $out/bin/fifine-control-deck \
      "''${makeWrapperArgs[@]}" --add-flags "-m fifine_deck"
    makeWrapper ${python}/bin/python3 $out/bin/fifine-deck-probe \
      "''${makeWrapperArgs[@]}" --add-flags "$share/probe_device.py"
  '';

  meta = {
    description = "Native Linux control app for the fifine / Mirabox Stream Dock (293V3, USB 3142:0060)";
    homepage = "https://github.com/ZoutMax/FifineControlDeck";
    license = lib.licenses.mit;
    platforms = [ "x86_64-linux" ];
    mainProgram = "fifine-control-deck";
  };
}
