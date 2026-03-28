{
  lib,
  swiftPackages,
}:

swiftPackages.stdenv.mkDerivation {
  pname = "nixbar";
  version = "1.0.0";

  src = lib.cleanSourceWith {
    src = ./.;
    filter =
      path: _type:
      let
        baseName = baseNameOf path;
      in
      baseName != ".build" && baseName != ".DS_Store";
  };

  nativeBuildInputs = with swiftPackages; [
    swift
    swiftpm
  ];

  buildPhase = ''
    swift build -c release
  '';

  installPhase = ''
    mkdir -p $out/Applications/NixBar.app/Contents/{MacOS,Resources}
    cp .build/release/NixBar $out/Applications/NixBar.app/Contents/MacOS/

    cat > $out/Applications/NixBar.app/Contents/Info.plist <<EOF
    <?xml version="1.0" encoding="UTF-8"?>
    <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
    <plist version="1.0">
    <dict>
      <key>CFBundleName</key>
      <string>NixBar</string>
      <key>CFBundleIdentifier</key>
      <string>com.alex.nixbar</string>
      <key>CFBundleVersion</key>
      <string>1.0</string>
      <key>CFBundleShortVersionString</key>
      <string>1.0</string>
      <key>CFBundlePackageType</key>
      <string>APPL</string>
      <key>CFBundleExecutable</key>
      <string>NixBar</string>
      <key>LSUIElement</key>
      <true/>
      <key>LSMinimumSystemVersion</key>
      <string>14.0</string>
    </dict>
    </plist>
    EOF
  '';

  meta = {
    description = "macOS menu bar app for managing Nix system configuration";
    platforms = lib.platforms.darwin;
  };
}
