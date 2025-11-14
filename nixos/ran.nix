# vim: shiftwidth=4 tabstop=4 noexpandtab
{ config, pkgs, modulesPath, ... }:

{
	networking.hostName = "Ran";
	imports = [
		./ran-hardware.nix
		./common.nix
		./linux.nix
		./linux-gui.nix
		./dev.nix
		./resources.nix
		(modulesPath + "/installer/scan/not-detected.nix")
	];

	nixpkgs.config.allowUnfree = true;

	environment.systemPackages = [
		pkgs.neovide
		pkgs.cider
	];

	services.searx = {
		enable = true;
		settings.server.secret_key = "meowmeowmeow";
	};

	# Allow resource limits to be calculated automatically.
	resources.memory = 16;
	resources.cpus = 12;

	services.fwupd.enable = true;

	# Non-NixOS-generated hardware configuration.
	hardware.cpu.amd.updateMicrocode = true;

	# This value determines the NixOS release from which the default
	# settings for stateful data, like file locations and database versions
	# on your system were taken. It‘s perfectly fine and recommended to leave
	# this value at the release version of the first install of this system.
	# Before changing this value read the documentation for this option
	# (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
	system.stateVersion = "23.11"; # Did you read the comment?
}
