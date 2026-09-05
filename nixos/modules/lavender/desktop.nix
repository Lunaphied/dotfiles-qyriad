{ config, lib, pkgs, ... }:
let
  cfg = config.services.lavenderDesktop;
  hs = config.services.headlessSway;
  p = cfg.palette;
  hash = c: "#${c}";
  mod = cfg.modifier;

  # --- wallpaper: deep indigo with a lavender glow top-left and a geranium glow bottom-right ----------------------
  # The faint noise dithers out banding (H.264 hates banding in dark gradients); JPEG keeps it to ~0.4 MB.
  glowWallpaper = pkgs.runCommand "lavender-glow.jpg" { nativeBuildInputs = [ pkgs.imagemagick ]; } ''
    magick -size 3840x2160 gradient:'${hash p.bgAlt}-${hash p.bg}' \
      \( -size 2800x2800 -define gradient:radius=1400 radial-gradient:'#5a3f9e-black' \) -geometry -900-1100 -compose screen -composite \
      \( -size 2400x2400 -define gradient:radius=1200 radial-gradient:'#9c2c4a-black' \) -geometry +2200+900 -compose screen -composite \
      -attenuate 0.03 +noise Gaussian -quality 94 \
      jpg:$out
  '';

  # Classic early-90s SGI demo render: gradient sky, perspective checker floor, glossy shaded spheres with soft shadows.
  # Drawn at half size and upscaled; built stepwise because one long -composite chain mis-handles -geometry state.
  sgiWallpaper = pkgs.runCommand "lavender-sgi.jpg" { nativeBuildInputs = [ pkgs.imagemagick ]; } ''
    W=1920; H=1080; HZ=530
    comp() { magick "$1" "$2" -geometry "+$3+$4" -compose over -composite "$5"; }
    sphere() { # size cx cy radius light dark out
      magick -size "$1"x"$1" -define gradient:center=$2,$3 -define gradient:radius=$(( $4 * 3 / 2 )) radial-gradient:"$5-$6" fill.png
      magick -size "$1"x"$1" xc:black -fill white -draw "circle $(( $1 / 2 )),$(( $1 / 2 )) $(( $1 / 2 )),$(( $1 / 2 - $4 ))" mask.png
      magick fill.png mask.png -alpha off -compose CopyOpacity -composite "$7"
    }
    magick -size 160x160 pattern:checkerboard -colorspace gray -auto-level +level-colors '#2b1f55,${hash p.lavender}' -scale 500% floor_src.png
    magick floor_src.png -alpha set -virtual-pixel background -background none -set option:distort:viewport "$W"x"$H"+0+0 \
      -distort Perspective "0,0 750,$HZ  800,0 1170,$HZ  800,800 4500,$H  0,800 -2580,$H" floor.png
    magick floor.png -crop "$W"x$(( H - HZ ))+0+$HZ +repage floor_low.png
    magick -size "$W"x"$H" xc:'#7a5fd0' bg.png
    magick -size "$W"x"$HZ" gradient:'#05030f-#7a5fd0' sky.png
    magick -size "$W"x260 gradient:'rgba(122,95,208,1)-rgba(122,95,208,0)' fog.png
    magick -size 700x130 xc:none -fill 'rgba(0,0,0,0.5)' -draw 'ellipse 350,65 260,45 0,360' -blur 0x15 sh1.png
    magick -size 500x100 xc:none -fill 'rgba(0,0,0,0.45)' -draw 'ellipse 250,50 170,30 0,360' -blur 0x12 sh2.png
    sphere 400 145 130 180 '#ffd0da' '#a8284a' sp1.png
    sphere 300 110 95 135 '#ffffff' '#4a37a0' sp2.png
    comp bg.png sky.png 0 0 a.png
    comp a.png floor_low.png 0 $HZ b.png
    comp b.png fog.png 0 $(( HZ - 1 )) c.png
    comp c.png sh1.png 500 505 d.png
    comp d.png sh2.png 1225 590 e.png
    comp e.png sp1.png 650 165 f.png
    comp f.png sp2.png 1275 280 g.png
    magick g.png -resize 200% -attenuate 0.03 +noise Gaussian -quality 94 jpg:$out
  '';
  wallpaper = { glow = glowWallpaper; sgi = sgiWallpaper; }.${cfg.wallpaper};

  # --- helper scripts ----------------------------------------------------------------------------------------------
  fuzzelConf = pkgs.writeText "fuzzel.ini" ''
    [main]
    font=${cfg.uiFont}:size=13
    prompt="✿  "
    icon-theme=Papirus-Dark
    terminal=${cfg.terminal} --
    width=44
    lines=9
    horizontal-pad=24
    vertical-pad=16
    inner-pad=8
    line-height=26

    [colors]
    background=${p.bg}f2
    text=${p.text}ff
    prompt=${p.geranium}ff
    input=${p.text}ff
    match=${p.geranium}ff
    selection=${p.surface}ff
    selection-text=${p.text}ff
    selection-match=${p.geranium}ff
    border=${p.lavender}ff

    [border]
    width=2
    radius=14
  '';
  fuzzelCmd = "${pkgs.fuzzel}/bin/fuzzel --config ${fuzzelConf}";

  # Click-to-focus window list (there is no alt-tab for floating windows in plain sway).
  windowSwitcher = pkgs.writeShellApplication {
    name = "lavender-windows";
    runtimeInputs = [ pkgs.sway pkgs.jq pkgs.fuzzel pkgs.coreutils pkgs.gnused ];
    text = ''
      list=$(swaymsg -t get_tree | jq -r '
        [.. | objects | select((.type == "con" or .type == "floating_con") and ((.pid // 0) > 0))][]
        | "\(.id)\t\(.app_id // .window_properties.class // "?")  ·  \(.name // "")"')
      [ -n "$list" ] || exit 0
      idx=$(printf '%s\n' "$list" | cut -f2- | fuzzel --config ${fuzzelConf} --dmenu --index --prompt='⧉  ' --width=60 --lines=8) || exit 0
      id=$(printf '%s\n' "$list" | sed -n "$((idx + 1))p" | cut -f1)
      swaymsg "[con_id=$id] focus" >/dev/null
    '';
  };

  # Snap the focused window to part of the usable area (the workspace rect excludes the bar).
  snap = pkgs.writeShellApplication {
    name = "lavender-snap";
    runtimeInputs = [ pkgs.sway pkgs.jq ];
    text = ''
      dir=''${1:?usage: lavender-snap left|right|full|center}
      read -r x y w h < <(swaymsg -t get_workspaces | jq -r '.[] | select(.focused) | .rect | "\(.x) \(.y) \(.width) \(.height)"')
      g=${toString cfg.gap}        # gap between two snapped windows (get_workspaces already insets the outer gap)
      case $dir in
        left)   nx=$x;                 ny=$y; nw=$((w / 2 - g / 2)); nh=$h ;;
        right)  nx=$((x + w / 2 + g / 2)); ny=$y; nw=$((w / 2 - g / 2)); nh=$h ;;
        full)   nx=$x;                 ny=$y; nw=$w;                nh=$h ;;
        center) nw=$((w * 6 / 10)); nh=$((h * 7 / 10)); nx=$((x + (w - nw) / 2)); ny=$((y + (h - nh) / 2)) ;;
        *) echo "unknown position: $dir" >&2; exit 2 ;;
      esac
      swaymsg "floating enable, move absolute position $nx px $ny px, resize set width $nw px height $nh px, move absolute position $nx px $ny px" >/dev/null
    '';
  };

  # Clipboard client that can offer several MIME types at once (wl-copy offers only one); see lavender-clip.c.
  lavenderClip = pkgs.stdenv.mkDerivation {
    pname = "lavender-clip";
    version = "1";
    dontUnpack = true;
    nativeBuildInputs = [ pkgs.pkg-config pkgs.wayland-scanner ];
    buildInputs = [ pkgs.wayland ];
    buildPhase = ''
      xml=${pkgs.wlr-protocols}/share/wlr-protocols/unstable/wlr-data-control-unstable-v1.xml
      wayland-scanner client-header $xml wlr-data-control-unstable-v1-client-protocol.h
      wayland-scanner private-code $xml wlr-data-control-unstable-v1-protocol.c
      $CC -O2 -Wall -Wextra -I. -o lavender-clip ${./lavender-clip.c} wlr-data-control-unstable-v1-protocol.c \
        $(pkg-config --cflags --libs wayland-client)
    '';
    installPhase = "install -Dm755 lavender-clip $out/bin/lavender-clip";
    meta.mainProgram = "lavender-clip";
  };

  # Region screenshot: saved as a PNG, and offered on the clipboard in every form a paste target might want:
  # the image (image/png: browsers, chat apps, editors), the file (text/uri-list and x-special/gnome-copied-files:
  # file managers and upload dialogs) and the path as text (terminals, text fields). The path is also on the primary
  # selection (middle-click). Optional $1 is a "x,y wxh" geometry, skipping the interactive selection (for testing).
  screenshot = pkgs.writeShellApplication {
    name = "lavender-screenshot";
    runtimeInputs = [ pkgs.grim pkgs.slurp lavenderClip pkgs.libnotify pkgs.coreutils ];
    text = ''
      dir="${cfg.screenshotDir}"
      mkdir -p "$dir"
      file="$dir/screenshot-$(date +%Y%m%d-%H%M%S).png"
      region=''${1:-$(slurp -b '${p.bg}99' -c '${p.geranium}ff' -s '${p.lavender}33' -w 2)} || exit 0
      grim -g "$region" "$file"
      uri="file://''${file// /%20}"
      text_types='text/plain;charset=utf-8,text/plain,UTF8_STRING,STRING'
      lavender-clip \
        --type image/png --file "$file" \
        --type text/uri-list --text "$uri"$'\r\n' \
        --type x-special/gnome-copied-files --text "copy"$'\n'"$uri" \
        --type "$text_types" --text "$file"
      lavender-clip --primary --type "$text_types" --text "$file"
      notify-send --app-name=Screenshot --icon="$file" 'Screenshot saved' "$file" || true
    '';
  };

  # --- bar (Ironbar: a Rust GTK bar; wlr-foreign-toplevel taskbar, sway workspaces, tray) ----------------------------
  ironbarConf = pkgs.writeText "ironbar.json" (builtins.toJSON {
    position = "top";
    height = 36;
    anchor_to_edges = true;
    margin = { top = cfg.gap; left = cfg.gap; right = cfg.gap; bottom = 0; };
    icon_theme = "Papirus-Dark";
    start = [
      { type = "custom"; class = "launch"; bar = [ { type = "button"; name = "launch-button"; label = "✿"; on_click = "!${fuzzelCmd}"; } ]; }
      { type = "workspaces"; }
      {
        type = "launcher";
        show_names = cfg.taskbarLabels;
        icon_size = 20;
        truncate = { mode = "end"; max_length = 22; };
      }
    ];
    center = [ { type = "clock"; format = "%a %d %b   %H:%M"; } ];
    end = [
      { type = "sys_info"; format = [ "cpu {cpu_percent}%" "mem {memory_percent}%" ]; interval = { cpu = 3; memory = 5; }; }
      { type = "tray"; icon_size = 18; }
    ];
  });

  ironbarStyle = pkgs.writeText "ironbar.css" ''
    * { font-family: "${cfg.uiFont}", "${cfg.monoFont}", sans-serif; font-size: 13px; border: none; border-radius: 0; box-shadow: none; }
    window, #bar { background: transparent; color: ${hash p.text}; }
    box, button, label { background: transparent; }

    .launch, .workspaces, .launcher, .clock, .sysinfo, .tray {
      background: alpha(${hash p.bg}, 0.88);
      border-radius: 12px;
      padding: 0 8px;
      margin: 0 4px;
    }
    .launch button { color: ${hash p.geranium}; font-size: 17px; padding: 0 8px; }
    .launch button:hover { background: ${hash p.surface}; border-radius: 8px; }
    .workspaces .item { color: ${hash p.subtle}; padding: 0 8px; margin: 4px 1px; border-radius: 8px; }
    .workspaces .item.focused { background: ${hash p.surface}; color: ${hash p.lavender}; }
    .workspaces .item.urgent { background: ${hash p.geranium}; color: ${hash p.bg}; }
    .launcher .item { padding: 0 6px; margin: 4px 2px; border-radius: 8px; color: ${hash p.subtle}; }
    .launcher .item:hover { background: ${hash p.surface}; }
    .launcher .item.open { color: ${hash p.text}; }
    .launcher .item.focused { background: ${hash p.surface}; box-shadow: inset 0 -2px ${hash p.geranium}; }
    .launcher .item.urgent { background: ${hash p.geranium}; }
    .clock { font-weight: 600; }
    .sysinfo { color: ${hash p.lavender}; }
    .sysinfo > .item + .item { color: ${hash p.geranium}; margin-left: 10px; }
    popover, popover contents, .popup { background: ${hash p.bg}; border-radius: 12px; color: ${hash p.text}; }
  '';

  # Starts the shell once sway is up. Order matters:
  #  1. Publish WAYLAND_DISPLAY / XDG_CURRENT_DESKTOP to the user manager and the D-Bus activation environment, so
  #     portals pick the sway config instead of another desktop's (Ran is a Plasma host).
  #  2. Start lavender-session.target (BindsTo graphical-session.target). xdg-desktop-portal has
  #     Requisite=graphical-session.target, so without this it never starts and anything asking it for the colour
  #     scheme (GTK/libadwaita apps, Waybar) stalls for 25 s on a D-Bus timeout. headless sway never starts that
  #     target on its own.
  #  3. Run the bar, restarted if it dies (it can crash when lavenderctl removes an output).
  shellScript = pkgs.writeShellScript "lavender-shell" ''
    ${pkgs.dbus}/bin/dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP SWAYSOCK
    ${config.systemd.package}/bin/systemctl --user start lavender-session.target
    while :; do
      ${pkgs.ironbar}/bin/ironbar --config ${ironbarConf} --theme ${ironbarStyle} || true
      sleep 1
    done
  '';

  makoConf = pkgs.writeText "mako.conf" ''
    font=${cfg.uiFont} 12
    background-color=${hash p.bg}ee
    text-color=${hash p.text}
    border-color=${hash p.lavender}
    border-size=2
    border-radius=12
    padding=14
    margin=${toString cfg.gap}
    width=360
    anchor=top-right
    default-timeout=6000
    icons=1

    [urgency=high]
    border-color=${hash p.geranium}
    default-timeout=0
  '';

  # Copland OS Enterprise: the Navi's operating system in Serial Experiments Lain. A dark, blue-washed NeXTSTEP-ish
  # interface with hologram-cyan accents. The series gives no palette, so these colours are an interpretation:
  # deep navy ground, brushed-silver chrome, ice-white text, cyan "hologram" highlights, Lain-red for alerts.
  kittyConf = pkgs.writeText "kitty.conf" ''
    font_family      ${cfg.monoFont}
    font_size        12.0
    window_padding_width 10
    cursor_shape block
    cursor_blink_interval 0
    enable_audio_bell no
    confirm_os_window_close 0
    scrollback_lines 10000
    # Each remote wheel click scrolls this many lines (kitty's default of 5 is a lot over a VNC wheel).
    wheel_scroll_multiplier 3.0
    mouse_hide_wait 3.0
    background_opacity 0.95
    tab_bar_edge top
    tab_bar_style separator
    tab_separator " ┃ "
    tab_title_template " {title} "
    active_tab_font_style bold

    foreground #cfe3ff
    background #0b1220
    selection_foreground #0b1220
    selection_background #5fd3ff
    cursor #5fd3ff
    cursor_text_color #0b1220
    url_color #7db8ff
    active_border_color #c0c8d4
    inactive_border_color #8a94a6
    active_tab_foreground #0b1220
    active_tab_background #c0c8d4
    inactive_tab_foreground #8a94a6
    inactive_tab_background #1a2d4f
    tab_bar_background #0b1220

    color0  #0b1220
    color8  #4f5d75
    color1  #e0405a
    color9  #ff6b81
    color2  #4fd1a1
    color10 #7ff0c0
    color3  #d9c26a
    color11 #f0dc8c
    color4  #4a8fe8
    color12 #7db8ff
    color5  #9b7ce8
    color13 #bda6ff
    color6  #5fd3ff
    color14 #9be8ff
    color7  #b8c2d0
    color15 #e8edf4
  '';
  kittyCmd = "${pkgs.kitty}/bin/kitty --config ${kittyConf}";

  # The matching Neovim colorscheme (same palette), on the runtimepath via XDG_DATA_DIRS (:colorscheme copland).
  coplandNvim = pkgs.runCommand "nvim-copland" { } "install -Dm644 ${./copland.lua} $out/share/nvim/site/colors/copland.lua";

  workspaceBinds = lib.concatMapStrings (n: ''
    bindsym ${mod}+${n} workspace number ${n}
    bindsym ${mod}+Shift+${n} move container to workspace number ${n}
  '') [ "1" "2" "3" "4" ];

  swayFragment = ''
    # ---- look -------------------------------------------------------------------------------------------------------
    output * bg ${wallpaper} fill ${hash p.bg}
    font pango:${cfg.uiFont} 11
    default_border normal 2
    default_floating_border normal 2
    titlebar_padding 12 5
    title_align left
    hide_edge_borders none
    gaps inner ${toString cfg.gap}
    gaps outer 0
    #                        border            background        text              indicator         child_border
    client.focused           ${hash p.lavender} ${hash p.surface} ${hash p.text}    ${hash p.geranium} ${hash p.lavender}
    client.focused_inactive  ${hash p.bgAlt}    ${hash p.bgAlt}   ${hash p.subtle}  ${hash p.bgAlt}    ${hash p.bgAlt}
    client.unfocused         ${hash p.bgAlt}    ${hash p.bg}      ${hash p.subtle}  ${hash p.bgAlt}    ${hash p.bgAlt}
    client.urgent            ${hash p.geranium} ${hash p.geranium} ${hash p.bg}      ${hash p.geranium} ${hash p.geranium}
    client.placeholder       ${hash p.bg}       ${hash p.bg}      ${hash p.subtle}  ${hash p.bg}       ${hash p.bg}
    client.background        ${hash p.bg}

    # ---- behaviour: a floating, click-to-focus desktop (tiling is still there via mod+t) --------------------------------
    for_window [app_id=".*"] floating enable
    for_window [class=".*"] floating enable
    focus_follows_mouse no
    mouse_warping none
    # Cmd+drag moves a window, Cmd+right-drag resizes it.
    floating_modifier ${cfg.mouseModifier} normal

    # ---- keys ---------------------------------------------------------------------------------------------------------
    # ${mod} is Ctrl+Cmd (Ctrl+Super): macOS and the viewer's menu claim bare Cmd chords and Ctrl+Option, and
    # Option+letter reaches the host as a composed character, so none of those can be used. Avoided on purpose:
    # Ctrl+Cmd+Q (lock screen), +Space (emoji), +F (viewer fullscreen), +D (dictionary), Ctrl+Shift+Cmd+3/4/5.
    bindsym ${mod}+Return exec ${cfg.terminal}
    bindsym ${mod}+r exec ${fuzzelCmd}
    bindsym ${mod}+Tab exec ${lib.getExe windowSwitcher}
    bindsym ${mod}+w kill
    bindsym ${mod}+m fullscreen toggle
    bindsym ${mod}+t floating toggle
    bindsym ${mod}+s exec ${lib.getExe screenshot}
    bindsym ${mod}+Left exec ${lib.getExe snap} left
    bindsym ${mod}+Right exec ${lib.getExe snap} right
    bindsym ${mod}+Up exec ${lib.getExe snap} full
    bindsym ${mod}+Down exec ${lib.getExe snap} center
    bindsym ${mod}+Shift+c reload
    ${workspaceBinds}
    # ---- shell --------------------------------------------------------------------------------------------------------
    exec ${pkgs.mako}/bin/mako --config ${makoConf}
    exec ${shellScript}
    ${cfg.extraConfig}
  '';
in
{
  options.services.lavenderDesktop = {
    enable = lib.mkEnableOption "the Lavender desktop shell (floating sway, ironbar, fuzzel, mako, kitty) for the headless session";
    modifier = lib.mkOption {
      type = lib.types.str;
      default = "Mod4+Control";
      description = ''
        Modifier combination for all window-manager keybindings. Default Ctrl+Cmd: nothing macOS or the viewer menu
        binds with it except lock screen (Q), emoji (Space), viewer fullscreen (F) and dictionary (D), none of which are used.
      '';
    };
    mouseModifier = lib.mkOption {
      type = lib.types.str;
      default = "Mod4";
      description = "Single modifier held to move (left drag) and resize (right drag) windows.";
    };
    terminal = lib.mkOption {
      type = lib.types.str;
      default = kittyCmd;
      defaultText = lib.literalExpression ''"''${pkgs.kitty}/bin/kitty --config <Copland>"'';
      description = "Terminal command for the keybinding and for Terminal=true launcher entries (run as `<terminal> -- cmd`).";
    };
    uiFont = lib.mkOption { type = lib.types.str; default = "Inter"; description = "Proportional UI font (bar, titlebars, launcher, notifications)."; };
    monoFont = lib.mkOption { type = lib.types.str; default = "JetBrainsMono Nerd Font"; description = "Monospace font (terminal) and glyph fallback."; };
    wallpaper = lib.mkOption {
      type = lib.types.enum [ "glow" "sgi" ];
      default = "glow";
      description = "Generated wallpaper: \"glow\" (soft lavender and geranium light) or \"sgi\" (a classic SGI-demo render: checker floor and glossy spheres).";
    };
    taskbarLabels = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Show window titles next to the taskbar icons. Off by default: on a laptop-sized display long titles crowd the bar (the title is still the tooltip).";
    };
    screenshotDir = lib.mkOption {
      type = lib.types.str;
      default = "$HOME/Pictures/Screenshots";
      description = "Where lavender-screenshot saves PNGs. Expanded by the shell, so $HOME works.";
    };
    gap = lib.mkOption { type = lib.types.ints.unsigned; default = 8; description = "Gap in pixels between windows and around the bar."; };
    palette = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = {
        bg = "1a1726";
        bgAlt = "241f38";
        surface = "2e2848";
        text = "e8e3f5";
        subtle = "9d94b8";
        lavender = "b9a7f0";
        geranium = "f2677f";
      };
      description = "Colours as RRGGBB without the leading #.";
    };
    extraConfig = lib.mkOption { type = lib.types.lines; default = ""; description = "Extra sway config appended after the desktop's."; };
  };

  config = lib.mkIf cfg.enable {
    assertions = [{ assertion = hs.enable; message = "lavenderDesktop requires headlessSway."; }];

    services.headlessSway.extraConfig = swayFragment;

    # See shellScript: gives xdg-desktop-portal the graphical-session.target it requires.
    systemd.user.targets.lavender-session = {
      description = "Lavender desktop session";
      bindsTo = [ "graphical-session.target" ];
      wants = [ "graphical-session-pre.target" ];
      after = [ "graphical-session-pre.target" ];
      partOf = [ "sway-headless.service" ];
      unitConfig.ConditionUser = hs.user;
    };

    # Apps started from the launcher or a keybinding inherit sway's environment, which headless-sway.nix keeps minimal.
    systemd.user.services.sway-headless = {
      path = [ "/run/current-system/sw" "/etc/profiles/per-user/${hs.user}" ];
      environment.XDG_DATA_DIRS = "/run/current-system/sw/share:/etc/profiles/per-user/${hs.user}/share";
    };

    environment.systemPackages = with pkgs; [ kitty neovim fuzzel grim slurp wl-clipboard papirus-icon-theme ] ++ [ lavenderClip coplandNvim ];

    fonts.enableDefaultPackages = lib.mkDefault true;
    fonts.packages = [ pkgs.inter pkgs.nerd-fonts.jetbrains-mono ];

    # Dark GTK apps with a matching icon theme (also what waybar's taskbar icons use).
    environment.etc."xdg/gtk-3.0/settings.ini".text = ''
      [Settings]
      gtk-application-prefer-dark-theme=1
      gtk-icon-theme-name=Papirus-Dark
      gtk-font-name=${cfg.uiFont} 11
    '';
    environment.etc."xdg/gtk-4.0/settings.ini".text = config.environment.etc."xdg/gtk-3.0/settings.ini".text;
  };
}
