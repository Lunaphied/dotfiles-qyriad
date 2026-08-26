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
		../modules/mount-usr.nix
		../modules/pam-u2f.nix
		#../modules/vr.nix
		(modulesPath + "/installer/scan/not-detected.nix")
	];

	nixpkgs.config.permittedInsecurePackages = [
		"ventoy-qt5-1.1.07"
		"olm-3.2.16"
	];

	programs.nix-ld = {
		enable = true;
		libraries = with pkgs; [
			# List by default
			zlib
			zstd
			stdenv.cc.cc
			curl
			openssl
			attr
			libssh
			bzip2
			libxml2
			acl
			libsodium
			util-linux
			xz
			systemd

			# My own additions
			libxcomposite
			libxtst
			libxrandr
			libxext
			libx11
			libxfixes
			libGL
			libva
			pipewire
			libxcb
			libxdamage
			libxshmfence
			libxxf86vm
			libelf

			# Required
			glib
			gtk2

			# Inspired by steam
			# https://github.com/NixOS/nixpkgs/blob/master/pkgs/by-name/st/steam/package.nix#L36-L85
			networkmanager
			vulkan-loader
			libgbm
			libdrm
			libxcrypt
			coreutils
			pciutils
			zenity
			# glibc_multi.bin # Seems to cause issue in ARM

			# # Without these it silently fails
			libxinerama
			libxcursor
			libxrender
			libxscrnsaver
			libxi
			libsm
			libice
			gnome2.GConf
			nspr
			nss
			cups
			libcap
			SDL2
			libusb1
			dbus-glib
			ffmpeg
			# Only libraries are needed from those two
			libudev0-shim

			# needed to run unity
			gtk3
			icu
			libnotify
			gsettings-desktop-schemas
			# https://github.com/NixOS/nixpkgs/issues/72282
			# https://github.com/NixOS/nixpkgs/blob/2e87260fafdd3d18aa1719246fd704b35e55b0f2/pkgs/applications/misc/joplin-desktop/default.nix#L16
			# log in /home/leo/.config/unity3d/Editor.log
			# it will segfault when opening files if you don’t do:
			# export XDG_DATA_DIRS=/nix/store/0nfsywbk0qml4faa7sk3sdfmbd85b7ra-gsettings-desktop-schemas-43.0/share/gsettings-schemas/gsettings-desktop-schemas-43.0:/nix/store/rkscn1raa3x850zq7jp9q3j5ghcf6zi2-gtk+3-3.24.35/share/gsettings-schemas/gtk+3-3.24.35/:$XDG_DATA_DIRS
			# other issue: (Unity:377230): GLib-GIO-CRITICAL **: 21:09:04.706: g_dbus_proxy_call_sync_internal: assertion 'G_IS_DBUS_PROXY (proxy)' failed

			# Verified games requirements
			libxt
			libxmu
			libogg
			libvorbis
			SDL
			SDL2_image
			glew110
			libidn
			tbb

			# Other things from runtime
			flac
			freeglut
			libjpeg
			libpng
			libpng12
			libsamplerate
			libmikmod
			libtheora
			libtiff
			pixman
			speex
			SDL_image
			SDL_ttf
			SDL_mixer
			SDL2_ttf
			SDL2_mixer
			libappindicator-gtk2
			libdbusmenu-gtk2
			libindicator-gtk2
			libcaca
			libcanberra
			libgcrypt
			libvpx
			librsvg
			libxft
			libvdpau
			# ...
			# Some more libraries that I needed to run programs
			pango
			cairo
			atk
			gdk-pixbuf
			fontconfig
			freetype
			dbus
			alsa-lib
			expat
			# for blender
			libxkbcommon

			libxcrypt-legacy # For natron
			libGLU # For natron

			# Appimages need fuse, e.g. https://musescore.org/fr/download/musescore-x86_64.AppImage
			fuse
			e2fsprogs
		];
	};
	# Reenable but don't add any default libraries, we'll wrap each application individually.

	services.usbmuxd.enable = true;

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

	nixpkgs.overlays = let
		kwin-useractions-no-overflow = pkgsFinal: pkgsPrev: {
			kdePackages = pkgsPrev.kdePackages.overrideScope (kdeFinal: kdePrev: {
				# Oh boy.
				# Ripples to:
				# - plasma-workspace
				# - plasma-desktop
				# - plasma-pa
				# - xdg-desktop-portal-kde
				# - kwin-x11
				# - plasma-browser-integration
				# - powerdevil
				# - kinfocenter
				# - kdeplasma-addons
				# - firefox (wrapper, thankfully)
				kwin = kdePrev.kwin.overrideAttrs (pkgFinal: pkgPrev: {
					nativeBuildInputs = pkgPrev.nativeBuildInputs or [ ] ++ [
						kdeFinal.extra-cmake-modules
					];
					patches = pkgPrev.patches or [ ] ++ [
						# This patch inlines the "More Actions" submenu, in the menu that you
						# get from right-clicking on a window's title bar.
						./../pkgs/kwin-useractions-no-overflow.patch
					];
				});

				# Ripples to:
				kdeconnect-kde = kdePrev.kdeconnect-kde.overrideAttrs (pkgFinal: pkgPrev: {
					cmakeFlags = pkgPrev.cmakeFlags or [ ] ++ [
						"-DBLUETOOTH_ENABLED=OFF"
					];
				});
			});
		};
	in [
		kwin-useractions-no-overflow
	];

	system.mount-usr.enable = true;
	nixpkgs.config.allowUnfree = true;

	# We currently use flatpak for Gajim because of some weird bug involving emoji support that is hard to debug.
	services.flatpak.enable = true;
	xdg.portal.enable = true;

	hardware.bluetooth.enable = true;
	hardware.enableAllFirmware = true;

	hardware.firmware = [
		(pkgs.callPackage ./bluez.nix {})
	];

	#nixpkgs.config.rocmSupport = true;

	#services.ollama = {
	#	enable = true;
	#	# Make ourselves appear as a gfx1030 instead of gfx1031... why.
	#	rocmOverrideGfx = "10.3.0";
	#	acceleration = "rocm";
	#	host = "100.120.38.64";
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

	programs.gpu-screen-recorder = {
		enable = true;
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
		# No blueray drive
		# makemkv
		valgrind
		ryubing
		davinci-resolve
		blender
		perf
		obs-cmd
		odin2
		#qyriad.nvtop-yuki
		libreoffice-qt6-fresh
		anki
		# We don't use beeper
		# beeper
		qyriad.originfox
		#jj-fzf
		qyriad.unfuck-seat
		qyriad.color-journal
		qyriad.glances
		footswitch
		syncplay
		gpu-screen-recorder-gtk
		config.programs.gpu-screen-recorder.package
		tana
		config.programs.nix-ld.package
	];

	programs.ghidra.enable = true;

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
	virtualisation = {
		libvirtd = {
			enable = true;
			qemu.vhostUserPackages = [ pkgs.virtiofsd ];
			# Look at https://github.com/QaidVoid/Complete-Single-GPU-Passthrough/blob/master/README.md
			#hooks.qemu = {
			#	"rocky8/prepare/begin/start.sh" = pkgs.writeText "start.sh" (lib.dedent ''
			#	# meow
			#	'');
			#};
		};
		podman.enable = true;
	};

	boot.plymouth = {
		enable = true;
		# Unfortunately things get decently blurry and this breaks the bgrt graphics for some reason.
		#extraConfig = lib.trim ''
		#	DeviceScale=4
		#'';

		#theme = "breeze";
	};

	# I think this is needed to support X11 forwarding?
	#programs.xwayland.enable = true;
	#programs.ssh.setXAuthLocation = true;
	#programs.ssh.forwardX11 = null;

	# Supposedly this is better
        # But ZFS is broken for this kernel version apparently...
	#boot.kernelPackages = pkgs.linuxKernel.packages.linux_zen;

	systemd.sleep.settings.Sleep.HibernateDelaySec = "30m";

	environment.etc."modprobe.d/snd_virmidi.conf".text = lib.dedent ''
		options snd_virmidi midi_devs=1
	'';

	environment.etc."modprobe.d/v4l2loopback.conf" = {
		text = (lib.trim ''
			options v4l2loopback video_nr=10,11,12 card_label=Virt0,Virt1,Virt2 exclusive_caps=1,1,1
		'') + "\n";
	};

	environment.extraOutputsToInstall = [
		"dnsutils"
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
