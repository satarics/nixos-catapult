# ==============================================================================
# ARCHITECTURE: Why do we need a 3-layer wrapper?
#
# 1. catapult-bin: Fetches the pre-built binary and patches static dependencies.
# 2. catapult-inner: Copies the binary to a writable directory (XDG_DATA_HOME).
#    WHY: Godot writes saves relative to the executable path, but /nix/store is read-only.
#    It also injects runtime libraries via LD_LIBRARY_PATH.
#    WHY: Godot 4.x loads graphics stacks via dlopen() at runtime, which autoPatchelfHook
#    cannot detect (it only reads DT_NEEDED).
# 3. catapult-fhs: Wraps the app in an FHS sandbox.
#    WHY: Catapult hardcodes absolute paths to utilities (e.g., `/bin/bash -c "tar ..."`),
#    which do not exist in NixOS.
# ==============================================================================
{ pkgs ? import <nixpkgs> {} }:

let
  version = "25.11a";

  # Godot 4.x dynamically loads X11/Wayland/OpenGL libraries at runtime via dlopen().
  # Since autoPatchelfHook only resolves static (DT_NEEDED) dependencies, we must manually
  # provide these via LD_LIBRARY_PATH in the wrapper script.
  runtimeLibs = with pkgs; [
    stdenv.cc.cc.lib
    zlib
    dbus
    fontconfig
    freetype
    
    # Use libglvnd instead of libGL: libglvnd dispatches requests to vendor-specific drivers.
    # Using libGL directly in LD_LIBRARY_PATH causes conflicts with proprietary drivers.
    libglvnd
    
    libpulseaudio
    alsa-lib
    libxkbcommon
    wayland
    
    udev

    libX11
    libXcursor
    libXext
    libXfixes
    libXi
    libXinerama
    libXrandr
    libXrender
    libxcb
    libXau
    libXdmcp

    sdl3
    sdl3-image
    sdl3-mixer
    sdl3-ttf

    SDL2
    SDL2_image
    SDL2_mixer
    SDL2_ttf

    sqlite
  ];

  libPath = pkgs.lib.makeLibraryPath runtimeLibs;

  catapult-bin = pkgs.stdenv.mkDerivation {
    pname = "catapult-bin";
    inherit version;

    src = pkgs.fetchurl {
      url = "https://github.com/qrrk/Catapult/releases/download/${version}/catapult-linux-x64-${version}";
      hash = "sha256-tpEHlXNCP+jaaExbR+xsNFxkdLJ+07HFAnM9azClxO0=";
    };

    dontUnpack = true;
    dontBuild = true;

    nativeBuildInputs = with pkgs; [ autoPatchelfHook ];
    buildInputs = runtimeLibs;

    installPhase = ''
      runHook preInstall
      install -Dm755 $src $out/libexec/catapult
      runHook postInstall
    '';

    meta = with pkgs.lib; {
      description = "Cross-platform launcher and content manager for Cataclysm: DDA and BN";
      homepage = "https://github.com/qrrk/Catapult";
      license = licenses.mit;
      mainProgram = "catapult";
      platforms = [ "x86_64-linux" ];
      sourceProvenance = with sourceTypes; [ binaryNativeCode ];
    };
  };

  catapult-inner = pkgs.writeShellScript "catapult-inner" ''
    set -euo pipefail

    # WORKAROUND: Godot engine writes saves and configs relative to the executable path.
    # Since /nix/store is strictly read-only, we must copy the binary to a mutable
    # user directory (XDG_DATA_HOME) before execution.
    DATA_DIR="''${CATAPULT_DATA_DIR:-''${XDG_DATA_HOME:-$HOME/.local/share}/catapult}"
    BIN="$DATA_DIR/catapult"
    STORE_BIN="${catapult-bin}/libexec/catapult"

    mkdir -p "$DATA_DIR"

    if [[ ! -x "$BIN" ]] || ! cmp -s "$STORE_BIN" "$BIN" 2>/dev/null; then
      echo "catapult: syncing binary from Nix store → $BIN" >&2
      cp -f "$STORE_BIN" "$BIN"
      chmod +x "$BIN"
    fi

    cd "$DATA_DIR"
    
    # Inject runtime libraries for Godot's dlopen() calls.
    export LD_LIBRARY_PATH="${libPath}''${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
    exec "$BIN" "$@"
  '';

  # FHS sandbox provides standard paths like /bin/bash, /usr/bin/tar, etc.,
  # which Catapult hardcodes in its internal Shell.execute() calls.
  catapult-fhs = pkgs.buildFHSEnv {
    name = "catapult";
    targetPkgs = p: with p; [
      bash
      coreutils
      findutils
      gnutar
      gzip
      bzip2
      xz
      zip
      unzip
      curl
      wget
    ];
    runScript = catapult-inner;
  };

  desktopItem = pkgs.makeDesktopItem {
    name = "catapult";
    desktopName = "Catapult";
    comment = "Launcher for Cataclysm: Dark Days Ahead and Bright Nights";
    exec = "catapult";
    
    # TODO(satarics): Replace "applications-games" fallback with the actual Catapult icon.
    # Need to extract the .png/.svg from the upstream release and install it to $out/share/icons.
    icon = "applications-games"; 
    
    categories = [ "Game" ];
    terminal = false;
  };

in
{
  inherit catapult-fhs desktopItem;
  package = catapult-fhs;
}