# vim: shiftwidth=4 tabstop=4 noexpandtab
{ config, pkgs, lib, modulesPath, ... }:

{
	# The below PAM config is cursed because PAM itself doesn't really support multiple authenticators in parallel.
	security.pam = {
		u2f = {
			# Enable using FIDO tokens if they're enrolled
			enable = true;

			# Allow the FIDO token alone to permit login and such.
			control = "sufficient";

			# We pretty much always want to give the prompt to touch the token when we go through the FIDO flow.
			settings.cue = true;
		};

		services = {
			sshd = {
				# We don't want to delay for 3 seconds waiting for this authenticator on a remote system.
				u2fAuth = false;
			};

			sudo = {
				rules.auth.u2f = {
					order = config.security.pam.services.sudo.rules.auth.unix.order + 10;

					# For now requiring the pin is up to the user's token configuration, they're free to allow
					# or deny specific tokens from the ability to login without a pin.
					settings.userpresence = lib.mkForce true;
				};
			};

			# Same as sudo? Unclear, need a proper test of Polkit.
			polkit-1 = {
				rules.auth.u2f = {
					order = config.security.pam.services.polkit-1.rules.auth.unix.order + 10;

					# For now requiring the pin is up to the user's token configuration, they're free to allow
					# or deny specific tokens from the ability to login without a pin.
					settings.userpresence = lib.mkForce true;
				};
			};

			# Login covers SDDM graphical proper logins along with all the typical login types you'd expect for Linux like VT's
			login = {
				rules.auth.u2f = {
					# Make sure we get put in after password entry is given so we don't have to wait for a timeout.
					order = config.security.pam.services.login.rules.auth.unix.order + 10;

					# For logins we obviously want to verify more than just the presence of a credential.
					settings.pinverification = 1;
				};
			};

			# KDE controls our lockscreen.
			kde = {
				rules.auth.u2f = {
					# Make sure we get put in after password entry is given so we don't have to wait for a timeout.
					order = config.security.pam.services.kde.rules.auth.unix.order + 10;

					# We want to ensure the user actually knows the token credentials for the lockscreen also.
					settings.pinverification = 1;
				};
			};

			# Almost works. We could probably add support to kscreenlocker to fix the flow here to be
			# "semi-interactive" like we want but testing this is... difficult.
			#kde-fingerprint = {
			#	rules.auth = {
			#		u2f = {
			#			# Make sure we get put in after password entry is given so we don't have to wait for a timeout.
			#			order = config.security.pam.services.kde-fingerprint.rules.auth.unix.order - 10;
			#
			#			# We want to ensure the user actually knows the token credentials for the lockscreen also.
			#			settings.pinverification = 1;
			#		};
			#	};
			#};
		};
	};
}
