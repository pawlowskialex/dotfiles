_:
let
  # nix-rosetta-builder's VM image has to be built on Linux, so the very first
  # switch needs nixpkgs' QEMU-based builder (prebuilt in cache.nixos.org).
  # Switch once with `bootstrap = true`, then flip it to false and switch
  # again; from then on the Rosetta builder can rebuild its own image.
  bootstrap = false;
in
{
  nix.linux-builder.enable = bootstrap;

  # Linux VM on Virtualization.framework (via Lima/vz) that builds
  # aarch64-linux natively and x86_64-linux through Rosetta 2.
  nix-rosetta-builder = {
    enable = !bootstrap;
    # Boot on the first Linux build, power off after onDemandLingerMinutes
    # idle, so the VM doesn't hold RAM all day.
    onDemand = true;
    cores = 8;
    memory = "16GiB";
  };
}
