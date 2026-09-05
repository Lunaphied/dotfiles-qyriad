{ config, lib, pkgs, ... }:
let
  cfg = config.services.headlessWayvnc;
  hs = config.services.headlessSway;

  # One wayvnc per sway output (neatvnc composites every display of an instance into a single encoder frame, which
  # would exceed the hardware H.264 size limit for multi-monitor layouts). The unit instance is the output name.
  configFile = pkgs.writeText "wayvnc-config" ''
    ${if cfg.enableAuth then ''
      enable_auth=true
      username=${cfg.username}
      private_key_file=@KEYDIR@/tls_key.pem
      certificate_file=@KEYDIR@/tls_cert.pem
      # Password is read from the file below; see README for generating it.
      ${lib.optionalString (cfg.passwordFile != null) "password=@PASSWORD@"}
    '' else ''
      # No VNC auth/encryption: only safe on a Unix socket or loopback behind an SSH tunnel (see assertion below).
      enable_auth=false
    ''}
  '';

  startScript = pkgs.writeShellScript "wayvnc-start" ''
    set -eu
    out=$1
    case "$out" in
      HEADLESS-[0-9]*) ;;
      *) echo "bad output name: $out" >&2; exit 2 ;;
    esac

    # See headless-sway.nix: don't trust an inherited XDG_RUNTIME_DIR.
    export XDG_RUNTIME_DIR=/run/user/$(id -u)
    d=$XDG_RUNTIME_DIR/lavender
    mkdir -p -m 700 "$d"

    conf=$d/wayvnc-$out.conf
    install -m600 ${configFile} "$conf"
    keydir="${cfg.keyDir}"
    sed -i "s|@KEYDIR@|$keydir|" "$conf"
    ${lib.optionalString (cfg.passwordFile != null) ''
      pw=$(cat ${cfg.passwordFile})
      sed -i "s|@PASSWORD@|$pw|" "$conf"
    ''}

    # Remove sockets left behind by a previous instance for this output.
    rm -f "$d/$out.vnc" "$d/ctl-$out"

    ${if cfg.transport == "unix" then ''
      listen=("unix:$d/$out.vnc")
    '' else ''
      # TCP: display N listens on base port + N - 1 (HEADLESS-1 keeps the base port).
      port=$(( ${toString cfg.port} + ''${out#HEADLESS-} - 1 ))
      listen=("${cfg.address}" "$port")
    ''}

    # wayvnc rate-limits frames to 30 fps unless told otherwise (hence --max-fps).
    exec ${pkgs.wayvnc}/bin/wayvnc --gpu --max-fps=${toString cfg.framerate} --config="$conf" --output="$out" \
      --socket="$d/ctl-$out" "''${listen[@]}"
  '';
in
{
  options.services.headlessWayvnc = {
    enable = lib.mkEnableOption "wayvnc with hardware H.264, one instance per headless output";
    transport = lib.mkOption {
      type = lib.types.enum [ "unix" "tcp" ];
      default = "unix";
      description = ''
        "unix": each instance listens on $XDG_RUNTIME_DIR/lavender/<output>.vnc (mode 0700 directory), reachable through
        `ssh -L local.sock:/run/user/UID/lavender/<output>.vnc` with no TCP port at all.
        "tcp": the previous behaviour; display N listens on port + N - 1 of `address`.
      '';
    };
    address = lib.mkOption {
      type = lib.types.str;
      default = "127.0.0.1";
      description = "TCP transport only: interface address to bind (LAN or Tailscale IP). Do not use 0.0.0.0.";
    };
    interface = lib.mkOption {
      type = lib.types.str;
      default = "lo";
      description = "TCP transport with authentication only: interface to open the firewall on.";
    };
    port = lib.mkOption { type = lib.types.port; default = 5900; description = "TCP transport only: base port (HEADLESS-1)."; };
    enableAuth = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        VeNCrypt TLS + password. Set false for the bundled macOS client (security type None), which needs the unix
        transport or address = "127.0.0.1" plus an SSH tunnel.
      '';
    };
    username = lib.mkOption { type = lib.types.str; default = "vnc"; description = "VNC login name when enableAuth is true."; };
    passwordFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = "Runtime path (e.g. agenix/sops secret) holding the VNC password; not copied to the store.";
    };
    keyDir = lib.mkOption {
      type = lib.types.str;
      default = "$HOME/.config/wayvnc";
      description = "Directory holding tls_key.pem / tls_cert.pem (generate with openssl, see README). Expanded by the shell.";
    };
    initialOutput = lib.mkOption {
      type = lib.types.str;
      default = "HEADLESS-1";
      description = "The output sway creates at start-up; its wayvnc instance is started automatically (others via lavenderctl).";
    };
    framerate = lib.mkOption { type = lib.types.int; default = 60; description = "Frame rate: wayvnc's --max-fps cap (its default is 30) and the H.264 rate-control framerate. Match the output refresh rate."; };
    bitrateKbps = lib.mkOption { type = lib.types.int; default = 40000; description = "H.264 constant bitrate in kbit/s per stream (read by the patched neatvnc)."; };
    lowPower = lib.mkOption { type = lib.types.bool; default = false; description = "Use the VAAPI low-power encoder mode (read by the patched neatvnc)."; };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      { assertion = hs.enable; message = "headlessWayvnc requires headlessSway."; }
      {
        assertion = cfg.transport == "unix" || cfg.enableAuth || cfg.address == "127.0.0.1";
        message = "headlessWayvnc: enableAuth = false over TCP is only allowed with address = \"127.0.0.1\" (use an SSH tunnel).";
      }
    ];

    services.headlessSway.startUnits = [ "wayvnc@${cfg.initialOutput}.service" ];

    # Unix sockets and loopback-only (tunnelled) setups need no firewall hole.
    networking.firewall.interfaces = lib.mkIf (cfg.transport == "tcp" && cfg.enableAuth) {
      ${cfg.interface}.allowedTCPPorts = [ cfg.port ];
    };

    systemd.user.services."wayvnc@" = {
      description = "wayvnc (VAAPI H.264) for %i";
      unitConfig.ConditionUser = hs.user; # see headless-sway.nix
      # Started by sway (services.headlessSway.startUnits) or by lavenderctl once WAYLAND_DISPLAY is exported
      # to the user manager.
      after = [ "sway-headless.service" ];
      requires = [ "sway-headless.service" ];
      partOf = [ "sway-headless.service" ];
      environment = {
        LIBVA_DRIVER_NAME = "radeonsi";
        NEATVNC_BITRATE_KBPS = toString cfg.bitrateKbps;
        NEATVNC_FRAMERATE = toString cfg.framerate;
        NEATVNC_LOW_POWER = if cfg.lowPower then "1" else "0";
      };
      path = [ pkgs.coreutils pkgs.gnused ];
      serviceConfig = {
        ExecStart = "${startScript} %i";
        Restart = "on-failure";
        RestartSec = 2;
      };
    };
  };
}
