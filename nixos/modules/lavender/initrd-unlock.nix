{ config, lib, ... }:
let
  cfg = config.services.initrdUnlock;
in
{
  options.services.initrdUnlock = {
    enable = lib.mkEnableOption "SSH in the initrd to enter the LUKS passphrase remotely";
    nicModules = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      description = ''
        Kernel module(s) for the NIC, loaded in the initrd so it can reach the network before the disk is
        unlocked. Find yours on the host with `lspci -k | grep -A3 -i ethernet` (e.g. "r8169", "igc", "e1000e").
      '';
    };
    authorizedKeys = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      description = "Public keys allowed to log in as root in the initrd (only able to unlock; not the real system).";
    };
    hostKeyFile = lib.mkOption {
      type = lib.types.str;
      default = "/etc/secrets/initrd/ssh_host_ed25519_key";
      description = ''
        Path (as a string, so it stays out of the Nix store) to a dedicated initrd host key. Create it with:
          sudo mkdir -p /etc/secrets/initrd && sudo ssh-keygen -t ed25519 -N "" -f /etc/secrets/initrd/ssh_host_ed25519_key
        Do not reuse the main sshd host key: the initrd lives on the unencrypted boot partition.
      '';
    };
    port = lib.mkOption { type = lib.types.port; default = 2222; description = "SSH port inside the initrd."; };
  };

  config = lib.mkIf cfg.enable {
    boot.initrd.availableKernelModules = cfg.nicModules;
    boot.initrd.systemd.enable = true;
    boot.initrd.systemd.network.enable = true;
    boot.initrd.systemd.network.networks."10-lan" = {
      matchConfig.Name = "en* eth*";
      networkConfig.DHCP = "yes";
    };
    boot.initrd.network.enable = true;
    boot.initrd.network.ssh = {
      enable = true;
      inherit (cfg) port authorizedKeys;
      hostKeys = [ cfg.hostKeyFile ];
    };
  };
}
