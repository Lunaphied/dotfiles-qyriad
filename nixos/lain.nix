# vim: shiftwidth=4 tabstop=4 noexpandtab
{ config, pkgs, lib, modulesPath, ... }:

let
	nixos-hardware = builtins.fetchTarball {
		url = "https://github.com/NixOS/nixos-hardware/archive/de6fc5551121c59c01e2a3d45b277a6d05077bc4.tar.gz";
		sha256 = "sha256:0yi5jb00zrlads7p00cp9cg74bxa6x1006wqcl6n2bhj6h6b3xvg";
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
		./modules/package-groups.nix
		(nixos-hardware + "/gpd/pocket-3")
		(modulesPath + "/installer/scan/not-detected.nix")
	];

	boot.plymouth.enable = true;

	zramSwap.enable = true;
	# Too tiny for this oops.
	boot.tmp.useTmpfs = lib.mkForce false;

	nixpkgs.config.allowUnfree = true;

	programs.gamemode.enable = true;

	programs.steam = {
		enable = true;
		remotePlay.openFirewall = true;
		dedicatedServer.openFirewall = true;
	};

	environment.systemPackages = with pkgs; [
		qyriad.steam-launcher-script
		#config.programs.steam.package.run
		neovide
		cider
		lutris
		#retroarchFull
		#retroarch
	];

	services.jenkins.enable = true;

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
