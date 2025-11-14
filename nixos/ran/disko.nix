{
  disko.devices = {

    disk = {
      root = {
        type = "disk";
        device = "/dev/disk/by-id/nvme-Samsung_SSD_990_PRO_2TB_S7KHNJ0X117346V";

        content = {
          type = "gpt";

					partitions = {
            ESP = {
              size = "16G";
              type = "EF00";
              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/boot/efi";
                mountOptions = [ "nofail" ];

								# For mkfs.vfat
								extraArgs = [ "-n" "ran-esp" ];
              };
            };

            zfs = {
              size = "100%";
              content = {
                type = "zfs";
                pool = "ran-zroot";
              };
            };
          };
        };
      };
    };

    zpool = {
      ran-zroot = {
        type = "zpool";

        rootFsOptions = {
          mountpoint = "none";
          compression = "zstd";
          acltype = "posixacl";
          xattr = "sa";
          "com.sun:auto-snapshot" = "true";
        };

        options.ashift = "12";

        datasets = {
          "root" = {
            type = "zfs_fs";
            options = {
              encryption = "aes-256-gcm";
              keyformat = "passphrase";
              #keylocation = "file:///tmp/secret.key";
              keylocation = "prompt";
            };
            mountpoint = "/";

          };

          "root/nix" = {
            type = "zfs_fs";
            options.mountpoint = "/nix";
            mountpoint = "/nix";
          };

          # README MORE: https://wiki.archlinux.org/title/ZFS#Swap_volume
          "root/swap" = {
            type = "zfs_volume";
            size = "32G";

            content = {
              type = "swap";
            };

            options = {
              volblocksize = "4096";
              compression = "zle";
              logbias = "throughput";
              sync = "always";
              primarycache = "metadata";
              secondarycache = "none";
              "com.sun:auto-snapshot" = "false";
            };
          };
        };
      };
    };

  };
}
