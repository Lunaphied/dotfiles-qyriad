{ config, lib, pkgs, ... }:
let
  cfg = config.services.lavenderctl;

  lavenderctl = pkgs.writers.writePython3Bin "lavenderctl" { doCheck = false; } (
    builtins.replaceStrings
      [ "@swaymsg@" "@systemctl@" ]
      [ "${pkgs.sway}/bin/swaymsg" "${config.systemd.package}/bin/systemctl" ]
      (builtins.readFile ./lavenderctl.py)
  );
in
{
  options.services.lavenderctl.enable = lib.mkOption {
    type = lib.types.bool;
    default = config.services.headlessSway.enable;
    defaultText = lib.literalExpression "config.services.headlessSway.enable";
    description = ''
      Install `lavenderctl`, the tool LavenderViewer runs over SSH to list/add/remove/resize the headless displays
      (and start/stop their wayvnc instances).
    '';
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ lavenderctl ];
  };
}
