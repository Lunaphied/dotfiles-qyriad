{ lib, pkgs, ... }:
{
  # Kernel choice and hardware.amdgpu.initrd are left to the host config (Ran pins zen and enables initrd amdgpu).
  hardware.enableRedistributableFirmware = lib.mkDefault true;

  hardware.graphics.enable = true; # Mesa: RADV (Vulkan) + radeonsi (VAAPI)

  environment.sessionVariables.LIBVA_DRIVER_NAME = "radeonsi";

  environment.systemPackages = with pkgs; [
    vulkan-tools
    libva-utils
    radeontop
    nvtopPackages.amd
  ];
}
