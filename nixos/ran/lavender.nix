# Headless Vulkan Wayland session + patched wayvnc (see ../modules/lavender). Remote use:
#   ssh -L 5900:127.0.0.1:5900 lunaphied@ran.local   then connect LavenderViewer to 127.0.0.1:5900
{ ... }:
{
	imports = [
		../modules/lavender/gpu-amd.nix
		../modules/lavender/headless-sway.nix
		../modules/lavender/wayvnc.nix
		../modules/lavender/lavenderctl.nix
		../modules/lavender/desktop.nix
		../modules/lavender/initrd-unlock.nix
	];

	nixpkgs.overlays = [ (import ../modules/lavender/overlays/wayvnc-patched.nix) ];

	services.headlessSway = {
		enable = true;
		user = "lunaphied";
	};

	services.lavenderDesktop.enable = true;

	services.headlessWayvnc = {
		enable = true;
		address = "127.0.0.1";
		enableAuth = false;
		interface = "lo"; # unused while enableAuth = false
	};

	# Remote ZFS unlock over SSH. Needs the initrd host key and your key before enabling; see
	# ../modules/lavender/initrd-unlock.nix (ZFS native encryption: run `systemd-tty-ask-password-agent`).
	services.initrdUnlock = {
		enable = true;
		nicModules = [ "r8169" ];
		authorizedKeys = [
			"ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMtKWle/o7YDRGkXRG5P0S23yvury35UXT0cyjT91CbF lunaphied@Mira"
		];
	};
}
