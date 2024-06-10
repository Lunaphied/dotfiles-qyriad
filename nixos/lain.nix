# vim: shiftwidth=4 tabstop=4 noexpandtab
{ config, pkgs, modulesPath, ... }:

let
	nixos-hardware = builtins.fetchTarball {
		url = "https://github.com/NixOS/nixos-hardware/archive/refs/heads/master.tar.gz";
		sha256 = "sha256:17pnp2rmjbg4b4nlh34r5lwd2531if87v00bb74zsvb894xjvyv2";
	};
in
{
	networking.hostName = "Lain";
	imports = [
		./lain-hardware.nix
		./common.nix
		./linux.nix
		./linux-gui.nix
		./dev.nix
		./resources.nix
		(nixos-hardware + "/gpd/pocket-3")
		(modulesPath + "/installer/scan/not-detected.nix")
	];

	zramSwap.enable = true;

	nixpkgs.config.allowUnfree = true;

	programs.steam.enable = true;

	environment.systemPackages = [
		pkgs.neovide
		pkgs.cider
		pkgs.lutris
	];

	#services.searx = {
	#	enable = true;
	#	settings.server.secret_key = "meowmeowmeow";
	#};

	# Allow resource limits to be calculated automatically.
	resources.memory = 16;
	resources.cpus = 8;

	services.fwupd.enable = true;

	# This value determines the NixOS release from which the default
	# settings for stateful data, like file locations and database versions
	# on your system were taken. It‘s perfectly fine and recommended to leave
	# this value at the release version of the first install of this system.
	# Before changing this value read the documentation for this option
	# (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
	system.stateVersion = "24.05"; # Did you read the comment?
}
