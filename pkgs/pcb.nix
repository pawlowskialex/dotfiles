# Diode's `pcb` CLI for Zener (Starlark) PCB designs.
#
# Not in nixpkgs. This repackages the prebuilt release binary that upstream's
# install.sh downloads. `pcb` is itself a launcher: each project pins its own
# toolchain (pcbc + stdlib), which gets downloaded at runtime into
# ~/Library/Application Support/pcb. KiCad 10 (homebrew cask) is only needed
# for `pcb layout`.
#
# Bump: curl -fsSL https://pcb.api.diode.computer/pcb/pcb-latest.json
{
  lib,
  stdenvNoCC,
  fetchurl,
}:

stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "pcb";
  version = "0.2.8";

  src = fetchurl {
    url = "https://pcb.api.diode.computer/pcb/pcb/v${finalAttrs.version}/pcb-aarch64-apple-darwin";
    hash = "sha256-fQrFcONW3y/1fBwO59eruvT9iNGpbYAcDn3PJ+0JDow=";
  };

  dontUnpack = true;
  # Upstream binary is signed and only links libSystem/libiconv; leave it untouched.
  dontFixup = true;

  installPhase = ''
    runHook preInstall
    install -Dm755 $src $out/bin/pcb
    runHook postInstall
  '';

  meta = {
    description = "Build tool for Zener PCB schematics; generates KiCad layouts";
    homepage = "https://github.com/diodeinc/pcb";
    license = lib.licenses.mit;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    platforms = [ "aarch64-darwin" ];
    mainProgram = "pcb";
  };
})
