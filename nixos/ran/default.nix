# vim: shiftwidth=4 tabstop=4 noexpandtab
{ config, pkgs, lib, modulesPath, ... }:

{
	imports = [
		./hardware.nix
		../common.nix
		../linux.nix
		../linux-gui.nix
		../dev.nix
		../resources.nix
		../mount-yorha.nix
		../modules/package-groups.nix
		../modules/pam-u2f.nix
		#../modules/vr.nix
		(modulesPath + "/installer/scan/not-detected.nix")
	];

	#programs.nix-ld = {
	#	enable = true;
	#	libraries = with pkgs; [
	#		ncurses5
	#		ncurses6
	#		xorg.libX11
	#		xorg.libXext
	#		xorg.libXrender
	#		xorg.libXtst
	#		xorg.libXi
	#		freetype
	#	];
	#};

	systemd.user = {
		sockets.dbus-monitor-pcap = {
			unitConfig.ConditionPathExists = "%t/bus";
			socketConfig.ListenFIFO = "%t/bus.pcap";
			wantedBy = [ "sockets.target" ];
		};
		services.dbus-monitor-pcap = {
			unitConfig.ConditionPathExists = [
				"%t/bus"
				"/run/current-system/sw/bin/dbus-monitor"
			];
			serviceConfig = {
				Type = "simple";
				ExecStart = "/run/current-system/sw/bin/dbus-monitor --session --pcap";
				Sockets = config.systemd.user.sockets.dbus-monitor-pcap.name;
				StandardOutput = "fd:${config.systemd.user.sockets.dbus-monitor-pcap.name}";
			};
		};
	};

	networking.hostName = "Ran";
	networking.hostId = "845de7ab";

	nixpkgs.config.allowUnfree = true;

	# We currently use flatpak for Gajim because of some weird bug involving emoji support that is hard to debug.
	services.flatpak.enable = true;
	xdg.portal.enable = true;

	hardware.bluetooth.enable = true;
	hardware.enableAllFirmware = true;

	#nixpkgs.config.rocmSupport = true;

	#services.ollama = {
	#	enable = true;
	#	# Make ourselves appear as a gfx1030 instead of gfx1031... why.
	#	rocmOverrideGfx = "10.3.0";
	#};

	services.fwupd.enable = true;
	services.resolved.enable = true;
	programs.mosh.enable = true;


	# Options from our custom NixOS module in ../resources.nix
	resources = {
		memory = 80;
		cpus = 32;
	};

	programs.gamemode.enable = true;

	programs.steam = {
		enable = true;
		remotePlay.openFirewall = true;
		dedicatedServer.openFirewall = true;
		gamescopeSession.enable = true;
	};

	nix.distributedBuilds = true;

	# I don't need steam hardware support. This is enabled by default with
	# `programs.steam.enable`.
	# Priority exactly 1 stronger than the default.
	#hardware.steam-hardware.enable = lib.mkForce false;

	programs.wireshark = {
		enable = true;
		package = pkgs.wireshark-qt;
		usbmon.enable = true;
	};
	users.users.qyriad.extraGroups = [ "wireshark" ];
	users.users.lunaphied.extraGroups = [ "wireshark" ];

	environment.systemPackages = with pkgs; [
		qyriad.steam-launcher-script
		config.programs.steam.package.run
		# We don't have a blu-ray drive lol.
		#makemkv
		valgrind
		ryubing
		shotcut
		davinci-resolve
		blender
		perf
		obs-cmd
		odin2
		#qyriad.nvtop-yuki
		libreoffice-qt6-fresh
		halloy
	];

	# Optimize Lix. Why not.
	nixpkgs.overlays = let
		optimizeLix = final: prev: {
			nix = prev.nix.override {
				stdenv = final.stdenvAdapters.impureUseNativeOptimizations final.clangStdenv;
			};
		};
	in [
		optimizeLix
	];

	security.pam.sshAgentAuth.enable = true;

	environment.etc."xkb" = {
		enable = true;
		source = pkgs.qyriad.xkeyboard_config-patched-inet;
	};

	services.hardware.openrgb.enable = true;


	# THESE ACTUALLY WORK!
    boot.consoleLogLevel = 3;
    boot.kernelParams = [ "amdgpu" "quiet" "udev.log_level=3" ];
	boot.loader.timeout = 0;
	boot.initrd = {
		verbose = false;
		systemd.enable = true;
	};

	programs.virt-manager.enable = true;
	virtualisation.libvirtd.enable = true;

	boot.plymouth = {
		enable = true;
		# Unfortunately things get decently blurry and this breaks the bgrt graphics for some reason.
		#extraConfig = lib.trim ''
		#	DeviceScale=4
		#'';

		#theme = "breeze";
	};

	services.invidious.enable = true;
	services.invidious.database.createLocally = true;
	services.postgresql.enable = true;

	# I think this is needed to support X11 forwarding?
	#programs.xwayland.enable = true;
	#programs.ssh.setXAuthLocation = true;
	#programs.ssh.forwardX11 = null;

	# Supposedly this is better
        # But ZFS is broken for this kernel version apparently...
	#boot.kernelPackages = pkgs.linuxKernel.packages.linux_zen;

	systemd.sleep.extraConfig = "HibernateDelaySec=30m";

	environment.etc."modprobe.d/v4l2loopback.conf" = {
		text = (lib.trim ''
			options v4l2loopback video_nr=10,11,12 card_label=Virt0,Virt1,Virt2 exclusive_caps=1,1,1
		'') + "\n";
	};

	environment.extraOutputsToInstall = [
		"dev"
	];

	systemd.network = {
		enable = true;
		# We're using NetworkManager.
		wait-online.enable = false;
		#netdevs."30-virt" = {
		#	netdevConfig.Name = "br13";
		#	netdevConfig.Kind = "bridge";
		#};
		#networks."30-virt" = {
		#	matchConfig.Name = "br13";
		#	networkConfig = {
		#		DHCP = "yes";
		#	};
		#};
	};

	#boot.kernelPackages = (pkgs.linuxPackagesFor pkgs.linux.override {
	#	extraStructuredConfig = with lib.kernel; {
	#		ISDN = yes;
	#		MISDN = yes;
	#		MISDN_DSP = yes;
	#		MISDN_L1OIP = yes;
	#	};
	#});

	services.freshrss = {
	};

	virtualisation.waydroid.enable = true;

	services.pipewire.extraConfig.pipewire-pulse = {
		"10-min-req" = {
			"pulse.min.req" = "1024/48000";
		};
	};

	# Non-NixOS-generated hardware configuration.
	hardware.cpu.amd.updateMicrocode = true;

	fonts.fontconfig.useEmbeddedBitmaps = true;
	fonts.fontconfig.subpixel.rgba = "rgb";

	# This value determines the NixOS release from which the default
	# settings for stateful data, like file locations and database versions
	# on your system were taken. It‘s perfectly fine and recommended to leave
	# this value at the release version of the first install of this system.
	# Before changing this value read the documentation for this option
	# (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
	system.stateVersion = "25.05"; # Did you read the comment?
}
