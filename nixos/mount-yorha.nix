# vim: shiftwidth=4 tabstop=4 noexpandtab
{ pkgs, ... }:

{
	systemd.mounts = let
		yorhaOpts = pkgs.qlib.genMountOpts {
			auto = null;
			_netdev = null;
			nofail = null;
			credentials = "/etc/secrets/yorha.cred";
			gid = "users";
			file_mode = "0764";
			dir_mode = "0775";
			vers = "3.1.1";
		};

		after = [
			"network-online.target"
			"multi-user.target"
			#"avahi-daemon.service"
		];

		requires = after;

		mountConfig = {
			TimeoutSec = "10s";
			Options = yorhaOpts;
		};

		unitConfig = {
			StartLimitIntervalSec = "30s";
			StartLimitBurst = "1";
		};

		wantedBy = [ "multi-user.target" ];

		media-yorha-media = {
			type = "cifs";
			what = "//yorha.local/Media";
			where = "/media/yorha/media";
			#enable = false;

			inherit after requires wantedBy mountConfig unitConfig;
		};

		media-yorha-archive = {
			type = "cifs";
			what = "//yorha.local/Backup";
			where = "/media/yorha/archive";
			#enable = false;

			inherit after requires wantedBy mountConfig unitConfig;
		};
	in [
		media-yorha-media
		media-yorha-archive
	];
}
