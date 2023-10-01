# vim: shiftwidth=4 tabstop=4 noexpandtab

{ config, pkgs, qyriad, ... }:

{

	# Enable GUI stuff in general.
	# Yes this says xserver. Yes this we're using Wayland. That's correct.
	services.xserver.enable = true;

	# Use a Wayland KDE Plasma desktop environment, with systemd integration.
	services.xserver = {

		displayManager = {
			sddm = {
				enable = true;
				autoNumlock = true;
				settings.General = {
					DisplayServer = "wayland";
					InputMethod = "ibus";
				};
			};
			defaultSession = "plasmawayland";
		};

		desktopManager = {
			plasma5.enable = true;
			plasma5.runUsingSystemd = true;
		};
	};

	# "A stop job is running for X11—" fuck off.
	systemd.services.display-manager.serviceConfig.TimeoutStopSec = "10";

	xdg.portal = {
		enable = true;
		extraPortals = [
			pkgs.xdg-desktop-portal-gtk
			pkgs.xdg-desktop-portal-kde
		];
	};

	# And also let Blink stuffs use Wayland.
	environment.sessionVariables = {
		NIXOS_OZONE_WL = "1";
	};

	# Enable sound with Pipewire.
	sound.enable = true;
	hardware.pulseaudio.enable = false;
	security.rtkit.enable = true;
	services.pipewire = {
		enable = true;
		alsa.enable = true;
		alsa.support32Bit = true;
		pulse.enable = true;
		#jack.enable = true;

		# use the example session manager (no others are packaged yet so this is enabled by default,
		# no need to redefine it in your config for now).
		#media-session.enable = true;
	};

	# FIXME: Is this necessary?
	services.xserver.libinput.enable = true;

	programs.gnupg.agent.pinentryFlavor = "qt";

	# Input method stuff.
	i18n.inputMethod = {
		enabled = "fcitx5";

		fcitx5.addons = with pkgs; [
			fcitx5-mozc
		];
	};

	# Enable udisks2.
	services.udisks2.enable = true;

	# A little bit cursed to put this in linux-gui, but generally this is the file that won't be sourced
	# for servers.
	networking.firewall.enable = false;

	environment.systemPackages = with pkgs; [
		alacritty
		mpv
		wl-clipboard
		ksshaskpass
		opera
		firefox
		obsidian
		discord
		calibre
		kicad
		krita
		# TODO: possibly switch to sddm.extraPackages if it's added
		# https://github.com/NixOS/nixpkgs/pull/242009 (nixos/sddm: enable Wayland support)
		weston
		dsview
		pulseview
	];

	# Used for noise suppression.
	#programs.noisetorch.enable = true;

	# Setup the terminal font we use, and make CJK render nicely.
	fonts.packages = [
		qyriad.nerdfonts
		pkgs.noto-fonts-cjk-sans
	];
	fonts.fontconfig.defaultFonts.monospace = [
		"InconsolataGo Nerd Font Mono"
	];


	# Enable reasonable default fonts for unicode and emoji.
	fonts.enableDefaultPackages = true;
}
