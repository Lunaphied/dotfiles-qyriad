# vim: shiftwidth=4 tabstop=4 noexpandtab
{ config, pkgs, modulesPath, ... }:

{
	imports = [
		./ran-hardware.nix
		./common.nix
		./linux.nix
		./linux-gui.nix
		./dev.nix
		./resources.nix
		(modulesPath + "/installer/scan/not-detected.nix")
	];

	networking.hostName = "Ran";

	nixpkgs.config.allowUnfree = true;
	

	hardware.bluetooth.enable = true;
	hardware.enableAllFirmware = true;

	services.fwupd.enable = true;
	services.tailscale.enable = true;
	services.resolved.enable = true;
	systemd.network.enable = true;

	# Options from our custom NixOS module in ./resources.nix
	resources = {
		memory = 64;
		cpus = 32;
	};

	environment.systemPackages = [ pkgs.tailscale pkgs.cider ];

	programs.steam.enable = true;
	services.hardware.openrgb.enable = true;
	

	boot.kernelPackages = pkgs.linuxKernel.packages.linux_lqx;
	# Needed for RGB RAM to be visible to OpenRGB, but maybe breaks sleep entirely oops.
	#boot.kernelParams = [ "acpi_enforce_resources=lax" ];

	# Non-NixOS-generated hardware configuration.
	hardware.cpu.amd.updateMicrocode = true;

	services.freshrss = {
	};

	# This value determines the NixOS release from which the default
	# settings for stateful data, like file locations and database versions
	# on your system were taken. It‘s perfectly fine and recommended to leave
	# this value at the release version of the first install of this system.
	# Before changing this value read the documentation for this option
	# (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
	system.stateVersion = "23.11"; # Did you read the comment?
}
