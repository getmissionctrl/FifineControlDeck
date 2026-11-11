# NixOS module: udev access for the deck and an optional autostart user service.
self:
{ config, lib, pkgs, ... }:
let
  cfg = config.programs.fifine-control-deck;
in
{
  options.programs.fifine-control-deck = {
    enable = lib.mkEnableOption "the fifine Control Deck app and udev access for the Stream Dock (USB 3142:*)";

    package = lib.mkOption {
      type = lib.types.package;
      default = self.packages.${pkgs.stdenv.hostPlatform.system}.default;
      defaultText = lib.literalExpression "fifine-control-deck.packages.\${system}.default";
      description = "The fifine-control-deck package.";
    };

    autostart = {
      enable = lib.mkEnableOption "a systemd user service that runs the deck in the graphical session";
      mode = lib.mkOption {
        type = lib.types.enum [ "hidden" "headless" ];
        default = "hidden";
        description = ''
          `hidden` runs the GUI with its window hidden (tray icon). Launching
          the app again raises that window, so the deck and the editor are one
          process. `headless` runs the key daemon only; the GUI and the daemon
          share a single-instance lock, so the GUI cannot open while it runs.
        '';
      };
      extraPath = lib.mkOption {
        type = lib.types.listOf lib.types.package;
        default = [ ];
        example = lib.literalExpression "[ pkgs.obs-cmd pkgs.curl ]";
        description = "Packages put on the service's PATH for \"Run shell command\" actions.";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ cfg.package ];

    # From a udev *package* at 70-, not services.udev.extraRules: TAG+="uaccess"
    # only takes effect from a file that sorts before systemd's 73-seat-late.rules,
    # and extraRules lands in 99-local.rules. Upstream's GROUP="plugdev" is
    # dropped (NixOS has no plugdev group).
    services.udev.packages = [
      (pkgs.writeTextFile {
        name = "fifine-deck-udev";
        destination = "/lib/udev/rules.d/70-fifine-deck.rules";
        text = ''
          SUBSYSTEM=="usb", ATTR{idVendor}=="3142", MODE="0660", TAG+="uaccess"
          KERNEL=="hidraw*", ATTRS{idVendor}=="3142", MODE="0660", TAG+="uaccess"
        '';
      })
    ];

    systemd.user.services.fifine-control-deck = lib.mkIf cfg.autostart.enable {
      description = "fifine Control Deck";
      wantedBy = [ "graphical-session.target" ];
      partOf = [ "graphical-session.target" ];
      after = [ "graphical-session.target" ];
      # User's login PATH (wpctl, hyprctl, notify-send…) plus extras, so shell
      # actions behave as they would in a terminal.
      path = cfg.autostart.extraPath ++ [ "/run/current-system/sw" "/etc/profiles/per-user/%u" ];
      serviceConfig = {
        ExecStart = "${lib.getExe cfg.package} --${cfg.autostart.mode}";
        Restart = "on-failure";
        RestartSec = 2;
        # 78 = EX_CONFIG: unreadable config; restarting cannot fix it.
        RestartPreventExitStatus = 78;
        # Only stop the app itself: apps launched from a key (launch_app,
        # run_command with `&`) live in this cgroup and would otherwise be
        # killed whenever the service stops or restarts.
        KillMode = "process";
      };
    };
  };
}
