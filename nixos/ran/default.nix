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
		../modules/dnssd.nix
		../modules/plasma-xdgdata-hack.nix
		../modules/pam-u2f.nix
		#../modules/vr.nix
		(modulesPath + "/installer/scan/not-detected.nix")
	];

	hacks.kde-plasma-xdg-datadirs-fix.enable = true;

	# This is dumb but it works.
	environment.etc."pam.d/weston-remote-access".text = lib.dedent ''
		account required /run/current-system/sw/lib/security/pam_unix.so # unix (order 11000)
		auth sufficient /run/current-system/sw/lib/security/pam_unix.so likeauth nullok try_first_pass # unix (order 12900)
		password sufficient /run/current-system/sw/lib/security/pam_unix.so nullok yescrypt # unix (order 10200)
	'';

	nixpkgs.config.permittedInsecurePackages = [
		"ventoy-qt5-1.1.07"
		"olm-3.2.16"
		"pnpm-10.29.2" # For Vesktop.
		"electron-40.10.5"
	];
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

	fileSystems."/media/data" = {
		device = "/dev/disk/by-label/YukiExtdata";
		fsType = "ext4";
		options = [ "discard" "nofail" ];
	};

	system.mount-usr.enable = true;

	systemd.user = {
		services.speech-dispatcher.unitConfig = {
			# Okay that breaks things.
			#StopWhenUnneeded = true;
		};
		# sockets.dbus-monitor-pcap = {
		# 	unitConfig.ConditionPathExists = "%t/bus";
		# 	socketConfig.ListenFIFO = "%t/bus.pcap";
		# 	wantedBy = [ "sockets.target" ];
		# };
		# services.dbus-monitor-pcap = {
		# 	unitConfig.ConditionPathExists = [
		# 		"%t/bus"
		# 		"/run/current-system/sw/bin/dbus-monitor"
		# 	];
		# 	serviceConfig = {
		# 		Type = "simple";
		# 		ExecStart = "/run/current-system/sw/bin/dbus-monitor --session --pcap";
		# 		Sockets = config.systemd.user.sockets.dbus-monitor-pcap.name;
		# 		StandardOutput = "fd:${config.systemd.user.sockets.dbus-monitor-pcap.name}";
		# 	};
		# };
	};

	networking.hostName = "Ran";
	networking.hostId = "845de7ab"; # Needed for Zfs.

	networking.useNetworkd = true;
	networking.nftables.enable = true;

	environment.etc."xkb" = {
		enable = true;
		source = pkgs.qyriad.xkeyboard_config-patched-inet;
	};

	security.wrappers."sslh-select" = {
		owner = "root";
		group = "wheel";
		source = lib.getExe' pkgs.sslh "sslh-select";
		capabilities = "cap_net_bind_service,cap_net_raw+ep";
		permissions = "u+rx,g+rx,o+r";
	};

	services.fwupd.enable = true;
	services.ratbagd.enable = true;

	services.printing.enable = lib.mkForce false;

	# Options from our custom NixOS module in ./resources.nix
	resources = {
		memory = 80;
		cpus = 32;
	};

	# Non-NixOS-generated hardware configuration.
	hardware.cpu.amd.updateMicrocode = true;

	boot.kernelModules = [
		# For MakeMKV on blu rays.
		"sg"
		# For virtual /dev/video devices.
		"v4l2loopback"
		# For DDC/CI.
		"i2c-dev"
		# For Waydroid.
		"ip_tables"
	];

	boot.loader.systemd-boot.consoleMode = "max";

	systemd.sleep.settings.Sleep.HibernateDelaySec = "30m";

	boot.binfmt.emulatedSystems = [
		"aarch64-linux"
	];

	# omg this hack seems no longer needed?
	#systemd.services."meow" = {
	#	after = [ "suspend.target" ];
	#	wantedBy = [ "suspend.target" ];
	#	script = lib.dedent ''
	#		sleep 10
	#		echo 1 | tee /sys/class/leds/*::capslock/brightness
	#		${lib.getExe' pkgs.acl "setfacl"} -m 'u:qyriad:rw' /dev/uinput
	#		${lib.getExe pkgs.sudo} -u qyriad ${lib.getExe pkgs.qyriad.unfuck-seat}
	#	'';
	#};

	#systemd.coredump.extraConfig = "MaxUse=1";

	environment.etc."modprobe.d/snd_virmidi.conf".text = lib.dedent ''
		options snd_virmidi midi_devs=1
	'';

	environment.etc."modprobe.d/v4l2loopback.conf".text = lib.dedent ''
		options v4l2loopback video_nr=10,11,12 card_label=Virt0,Virt1,Virt2 exclusive_caps=1,1,1
	'';

	environment.enableDebugInfo = true;
	environment.extraOutputsToInstall = [
		# Apparently this is how to get dig in our system path.
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

	# Currently disabled due to https://github.com/systemd/systemd/issues/39990
	#services.resolved.dnssd.services = {
	#	sshd.Service = {
	#		Name = "%H SSH Server";
	#		Type = "_ssh._tcp";
	#		Port = 22;
	#	};
	#};


	boot.enableContainers = true;
	programs.extra-container.enable = true;

	programs.firefox.autoConfig = lib.readFile pkgs.qyriad.fx-autoconfig;

	#containers.hass = {
	#	autoStart = false;
	#	config = { ... }: {
	#		imports = [ ../container-dataovermind.nix ];
	#		nixpkgs.pkgs = pkgs;
	#		services.openssh.enable = true;
	#		users.users.root.openssh.authorizedKeys.keys = [
	#			"ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDI6Tdxcbr3XSD2Ok2tUb4RJ3nOszqKklkqXUrgnFM1F cardno:26_907_287"
	#			"ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGuURQDdkB0wJGCCZra7TD7SRB+AJw3jlimZ40qq8OLE qyriad@Yuki"
	#		];
	#		system.stateVersion = "25.05";
	#	};
	#	additionalCapabilities = [ "CAP_NET_ADMIN" ];
	#	privateNetwork = true;
	#	bindMounts."/var/lib/ha-pluralkit" = {
	#		hostPath = "/home/qyriad/code/ha-pluralkit";
	#	};
	#};
	#networking.interfaces.enp93s0 = {
	#	name = "enp93s0";
	#	wakeOnLan.enable = true;
	#};

	virtualisation.waydroid.enable = true;

	services.pipewire.extraConfig.pipewire-pulse = {
		"10-min-req" = {
			"pulse.min.req" = "1024/48000";
		};
	};
	services.pipewire.raopOpenFirewall = true;

	services.inputplumber = {

	};

	services.syncthing = {
		enable = true;
		openDefaultPorts = true;
	};

	services.samba = {
		enable = true;
		openFirewall = true;
		nsswins = true;
		settings.public = {
			path = "/home/lunaphied";
			"read only" = "yes";
			"browsable" = "yes";
			"guest ok" = "yes";
		};
		settings.global = {
			workgroup = "WORKGROUP";
			"server string" = "ran";
			"netbios name" = "ran";
			"security" = "user";
			"hosts allow" = "192.168. 100.64. 127.0.0.1 localhost";
			"hosts deny" = "0.0.0.0/0";
			"guest account" = "nobody";
			"map to guest" = "bad user";
		};
	};

	nix.distributedBuilds = true;

	programs.gamemode.enable = true;

	programs.steam = {
		enable = true;
		remotePlay.openFirewall = true;
		dedicatedServer.openFirewall = true;
	};
	# I don't need steam hardware support. This is enabled by default with
	# `programs.steam.enable`.
	# Priority exactly 1 stronger than the default.
	hardware.steam-hardware.enable = lib.mkForce false;

	# We don't want it by default but sometimes I do.
	specialisation."nix-ld".configuration = { ... }: {
		programs.nix-ld.enable = true;
	};

	programs.nix-ld.libraries = with pkgs; [
		# Electron!
		glib
		nss
		gtk3
		libGL
		at-spi2-atk.out
		cairo.out
		cups.lib
		dbus.lib
		expat.out
		libgbm.out
		libxcb.out
		libxcomposite.out
		libxdamage.out
		libxext.out
		libxfixes.out
		libxkbcommon.out
		libxrandr.out
	];

	programs.wireshark = {
		enable = true;
		usbmon.enable = true;
	};
	users.users.qyriad.extraGroups = [ "wireshark" ];

	programs.gpu-screen-recorder = {
		enable = true;
	};

	environment.systemPackages = with pkgs; [
		qyriad.steam-launcher-script
		config.programs.steam.package.run
		# fails to download
		# makemkv
		valgrind
		ryubing
		davinci-resolve
		blender
		quickemu
		qyriad.qmlls
		perf
		obs-cmd
		odin2
		#qyriad.nvtop-yuki
		libreoffice-qt6-fresh
		anki
		beeper
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
		# For v4l2loopback-ctl
		linuxPackages.v4l2loopback
	];

	# This value determines the NixOS release from which the default
	# settings for stateful data, like file locations and database versions
	# on your system were taken. It‘s perfectly fine and recommended to leave
	# this value at the release version of the first install of this system.
	# Before changing this value read the documentation for this option
	# (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
	system.stateVersion = "25.05"; # Did you read the comment?

	# Needed for iOS tethering.
	services.usbmuxd.enable = true;

	# We currently use flatpak for Gajim because of some weird bug involving emoji support that is hard to debug.
	services.flatpak.enable = true;
	xdg.portal.enable = true;

	# Just deal with needing more firmware.
	nixpkgs.config.allowUnfree = true;
	hardware.bluetooth.enable = true;
	hardware.enableAllFirmware = true;

	# This is used for getting Bluez with a firmware for the dongle that came with the ISDN hardware.
	# It still didn't work but this did at least let it be seen.
	hardware.firmware = [
		(pkgs.callPackage ./bluez.nix {})
	];

	## Using ROCM on unsupported configs can be glitchy and probably works about as well as Vulkan anyway.
	#nixpkgs.config.rocmSupport = true;

	#services.ollama = {
	#	enable = true;
	#	# Make ourselves appear as a gfx1030 instead of gfx1031... why.
	#	rocmOverrideGfx = "10.3.0";
	#	acceleration = "rocm";
	#	host = "100.120.38.64";
	#};

	# I forgot why we enabled this.
	# services.resolved.enable = true;
	programs.mosh.enable = true;

	# Why not.
	programs.ghidra.enable = true;

	# I guess this does... something?
	security.pam.sshAgentAuth.enable = true;

	# Be able to configure our memory/keyboard/mouse/etc. lighting.
	services.hardware.openrgb.enable = true;

	# THESE ACTUALLY WORK! (For plymouth)
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
			# XXX: Not complete yet.
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

	fonts.fontconfig.useEmbeddedBitmaps = true;
	fonts.fontconfig.subpixel.rgba = "rgb";
}
