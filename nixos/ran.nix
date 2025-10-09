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
		./mount-yorha.nix
		./modules/package-groups.nix
		(modulesPath + "/installer/scan/not-detected.nix")
	];

	services.pipewire.extraConfig.pipewire = {
		"10-allowed-rates" = {
			"default.clock.allowed-rates" = [ 44100 48000 ];
		};
		## FIXME: figure out what of these are actually necessary/useful.
		#"10-capturecard-loopback-module"."context.modules" = let
		#	capturecard-loopback-module = {
		#		name = "libpipewire-module-loopback";
		#		args = {
		#			"capture.props" = {
		#				"node.name" = "AverMediaCapture";
		#				"node.nick" = "Capturecard Audio Loopback";
		#				"node.description" = "loopback-capturecard-capture";
		#				"stream.capture.source" = true;
		#				"target.object" = "alsa_input.usb-AVerMedia_Live_Gamer_EXTREME_3_5204246000283-02.iec958-stereo";
		#				"media.class" = "Stream/Input/Audio";
		#				# "port.group" = "capture";
		#				"application.name" = "LunaphiedConfig";
		#				"application.id" = "LunaphiedConfig";
		#				"media.role" = "Game";
		#				"node.group" = "lunaphied.loopback.capturecard";
		#				"node.loop.name" = "data-loop.0";
		#			};
		#			"playback.props" = {
		#				"node.name" = "AverMediaPlayback";
		#				"node.nick" = "Capturecard Audio Loopback";
		#				"node.description" = "AVerMedia Live Gamer EXTREME 3 (Audio Loopback)";
		#				"node.virtual" = false;
		#				"monitor.channel-volumes" = true;
		#				"stream.capture.sink" = true;
		#				"media.class" = "Stream/Output/Audio";
		#				"media.type" = "Audio";
		#				#"port.group" = "stream.0";
		#				 "port.group" = "playback";
		#				"application.name" = "LunaphiedConfig";
		#				"application.id" = "LunaphiedConfig";
		#				"media.category" = "Playback";
		#				"media.name" = "AVerMedia Audio Loopback";
		#				"media.role" = "Game";
		#				"node.group" = "lunaphied.loopback.capturecard";
		#				"node.loop.name" = "data-loop.0";
		#			};
		#		};
		#	};
		#in [
		#	capturecard-loopback-module
		#];
	};

	services.pipewire.extraConfig.pipewire-pulse = {
		"10-min-req" = {
			"pulse.min.req" = "1024/48000";
		};
	};

	networking.hostName = "Ran";

	nixpkgs.config.allowUnfree = true;

	services.flatpak.enable = true;
	xdg.portal.enable = true;

	hardware.bluetooth.enable = true;
	hardware.enableAllFirmware = true;

	services.fwupd.enable = true;
	services.resolved.enable = true;
	programs.mosh.enable = true;

	systemd.network.enable = true;
	networking.useNetworkd = true;


	# Options from our custom NixOS module in ./resources.nix
	resources = {
		memory = 64;
		cpus = 32;
	};

	programs.gamemode.enable = true;

	programs.steam = {
		enable = true;
		remotePlay.openFirewall = true;
		dedicatedServer.openFirewall = true;
		gamescopeSession.enable = true;
	};

	#services.displayManager.sddm = {
	#	enable = true;
	#	theme = "catppuccin-sddm-corners";
	#};

	environment.systemPackages = with pkgs; [
		catppuccin-sddm-corners
		qyriad.steam-launcher-script
		config.programs.steam.package.run
		makemkv
		valgrind
		ryujinx
		shotcut
		davinci-resolve
		blender
		jetbrains.rust-rover
		config.boot.kernelPackages.perf
		obs-cmd
		cider
		odin2
		retroarch-assets
		retroarchFull
		#konversation
		iodine
		networkmanager-iodine
		#cura
	];

	services.hardware.openrgb.enable = true;

	virtualisation.waydroid.enable = true;
	programs.virt-manager.enable = true;
	virtualisation.libvirtd = {
		enable = true;
	};

	nixos-boot = {
		# TODO: Fix the display of these, default is just blank looking, evil is small and not centered.
		enable = false;

		# Evil's plymouth script is a bit broken and looks weird.
		#theme = "evil-nixos";
		duration = 3.0;
	};

	services.invidious.enable = true;
	services.invidious.database.createLocally = true;
	services.postgresql.enable = true;

	# TODO: Fix the plymouth issue and also try to figure out a way to hide
	# other outputs. hm.

	#environment.variables = {
	#	ENABLE_HDR_WSI = "1";
	#};

	#programs.xwayland.enable = true;
	#programs.ssh.setXAuthLocation = true;
	#programs.ssh.forwardX11 = null;

	# Oops this doesn't support binder lol.
	boot.kernelPackages = pkgs.linuxKernel.packages.linux_zen;
	# Needed for RGB RAM to be visible to OpenRGB, but maybe breaks sleep entirely oops.
	#boot.kernelParams = [ "acpi_enforce_resources=lax" ];

	# Non-NixOS-generated hardware configuration.
	hardware.cpu.amd.updateMicrocode = true;

	services.freshrss = {
	};

	fonts.fontconfig.useEmbeddedBitmaps = true;
	fonts.fontconfig.subpixel.rgba = "rgb";

	# This value determines the NixOS release from which the default
	# settings for stateful data, like file locations and database versions
	# on your system were taken. It‘s perfectly fine and recommended to leave
	# this value at the release version of the first install of this system.
	# Before changing this value read the documentation for this option
	# (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
	system.stateVersion = "24.05"; # Did you read the comment?
}
