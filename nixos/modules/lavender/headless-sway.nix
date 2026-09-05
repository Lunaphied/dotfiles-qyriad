{ config, lib, pkgs, ... }:
let
  cfg = config.services.headlessSway;
  systemctl = "${config.systemd.package}/bin/systemctl";

  swayConfig = pkgs.writeText "sway-headless.conf" ''
    # Sway creates HEADLESS-1 itself on the headless backend (a second create_output would add an unconfigured
    # HEADLESS-2). Publish the Wayland/IPC sockets sway chose (the socket name is not fixed) to the user manager,
    # then start dependent units (wayvnc).
    exec ${pkgs.runtimeShell} -c '${systemctl} --user import-environment WAYLAND_DISPLAY SWAYSOCK${lib.optionalString (cfg.startUnits != [ ]) " && ${systemctl} --user start ${lib.concatStringsSep " " cfg.startUnits}"}'
    output HEADLESS-1 mode ${cfg.mode} scale ${toString cfg.scale}
    output * bg #202020 solid_color
    ${cfg.extraConfig}
  '';
in
{
  options.services.headlessSway = {
    enable = lib.mkEnableOption "headless sway session on the GPU";
    user = lib.mkOption { type = lib.types.str; description = "User that owns the session."; };
    renderNode = lib.mkOption {
      type = lib.types.str;
      default = "/dev/dri/renderD128";
      description = "DRM render node of the AMD GPU (Ran: card at 0b:00.0 is renderD128; check ls -l /dev/dri/by-path if an iGPU exists).";
    };
    renderer = lib.mkOption {
      type = lib.types.enum [ "vulkan" "gles2" ];
      default = "vulkan";
      description = "wlroots renderer. gles2 is the fallback if Vulkan misbehaves.";
    };
    mode = lib.mkOption { type = lib.types.str; default = "2560x1440@60Hz"; description = "Mode of the virtual HEADLESS-1 output."; };
    scale = lib.mkOption { type = lib.types.number; default = 1; description = "Output scale factor."; };
    extraConfig = lib.mkOption { type = lib.types.lines; default = ""; description = "Extra lines appended to the sway config."; };
    startUnits = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "User units to start once sway is up and WAYLAND_DISPLAY is exported (e.g. wayvnc.service).";
    };
  };

  config = lib.mkIf cfg.enable {
    programs.sway.enable = true;
    programs.sway.package = pkgs.sway; # wlroots with the Vulkan renderer

    users.users.${cfg.user} = {
      linger = true;
      extraGroups = [ "video" "render" ];
    };

    systemd.user.services.sway-headless = {
      description = "Headless sway (Vulkan)";
      wantedBy = [ "default.target" ];
      # User units are installed for every user's manager (including e.g. the SDDM greeter's), so
      # restrict this one to the session owner.
      unitConfig.ConditionUser = cfg.user;
      environment = {
        WLR_BACKENDS = "headless";
        WLR_RENDERER = cfg.renderer;
        WLR_RENDER_DRM_DEVICE = cfg.renderNode;
        WLR_LIBINPUT_NO_DEVICES = "1";
        XDG_SESSION_TYPE = "wayland";
      };
      # The NixOS sway wrapper runs under dbus-run-session, which needs dbus-daemon on PATH.
      # sway runs `exec` commands via sh found on PATH, so the unit needs bash too.
      path = [ pkgs.dbus pkgs.coreutils pkgs.bash ];
      # ~/.config/environment.d can leave XDG_RUNTIME_DIR malformed in the user manager (e.g. "/run/user/"
      # when a variable it references is unset), so derive it from the uid instead of trusting it.
      script = ''
        export XDG_RUNTIME_DIR=/run/user/$(id -u)
        exec ${pkgs.sway}/bin/sway --config ${swayConfig}
      '';
      serviceConfig = {
        Restart = "on-failure";
        RestartSec = 2;
      };
    };
  };
}
