# FHS environment for the Connect IQ simulator on NixOS (webkitgtk-4.0 is gone from current nixpkgs).
# Build: nix-build tools/nixos-sim.nix ; run: ./result/bin/connectiq-fhs -c ".../bin/simulator"
# Tip: run it on a hidden display, e.g. Xvfb :77, and export DISPLAY=:77 GDK_BACKEND=x11.
# FHS environment for the Connect IQ simulator on NixOS.
let
  pkgs = import (builtins.fetchTarball "https://github.com/NixOS/nixpkgs/archive/nixos-24.05.tar.gz") { };
in
pkgs.buildFHSEnv {
  name = "connectiq-fhs";
  targetPkgs = p: with p; [
    webkitgtk libsoup gtk3 glib cairo pango harfbuzz freetype fontconfig dejavu_fonts
    libsecret libjpeg8 libpng zlib expat libusb1 systemd stdenv.cc.cc.lib
    xorg.libX11 xorg.libXext xorg.libXxf86vm xorg.libSM xorg.libICE xorg.libXrender xorg.libXrandr xorg.libXi
    xorg.xorgserver imagemagick xdotool
    libxkbcommon libGL mesa atk at-spi2-atk at-spi2-core gdk-pixbuf libnotify gsettings-desktop-schemas
  ];
  runScript = "bash";
}
