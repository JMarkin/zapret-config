{ lib, config, pkgs, ... }:

let
  cfg = config.services.zapret2;
  inherit (lib) mkIf mkOption mkEnableOption mkPackageOption types optionalString toString;
in
{
  options.services.zapret2 = {
    enable = mkEnableOption "zapret2 DPI bypass service";

    package = mkPackageOption pkgs "zapret2" { };

    instance = mkOption {
      type = types.str;
      default = "nfqws0";
      description = "Instance name for nfqws2 config file";
    };

    rules = mkOption {
      type = with types; listOf str;
      default = [ ];
      example = [
        "--lua-init=@${pkgs.zapret2}/share/zapret2/lua/zapret-lib.lua"
        "--lua-init=@${pkgs.zapret2}/share/zapret2/lua/zapret-antidpi.lua"
        "--new"
        "--name=http"
        "--filter-tcp=80"
        "--lua-desync=multidisorder:pos=2"
      ];
      description = "nfqws2 command-line parameters";
    };

    configureFirewall = mkOption {
      type = types.bool;
      default = true;
      description = "Whether to setup firewall routing so system traffic is forwarded via this service";
    };

    httpSupport = mkOption {
      type = types.bool;
      default = true;
      description = "Whether to route http traffic on port 80";
    };

    httpMode = mkOption {
      type = types.enum [ "first" "full" ];
      default = "first";
      description = ''
        By default only the first packet is changed. Set to "full" if needed.
      '';
    };

    udpSupport = mkOption {
      type = types.bool;
      default = false;
      description = "Enable UDP routing";
    };

    udpPorts = mkOption {
      type = with types; listOf str;
      default = [ ];
      example = [ "50000:50099" "1234" ];
      description = "List of UDP ports to route";
    };

    qnum = mkOption {
      type = types.int;
      default = 200;
      description = "NFQUEUE queue number";
    };
  };

  config = mkIf cfg.enable (
    lib.mkMerge [
      {
        assertions = [
          {
            assertion = (builtins.length cfg.rules) != 0;
            message = "You have to specify zapret2 rules";
          }
          {
            assertion = cfg.udpSupport -> (builtins.length cfg.udpPorts) != 0;
            message = "You have to specify UDP ports or disable UDP support";
          }
          {
            assertion = !cfg.configureFirewall || !config.networking.nftables.enable;
            message = "You need to manually configure your firewall for Zapret2 when using nftables";
          }
        ];

        environment.etc."zapret2/${cfg.instance}.conf" = {
          text = lib.concatStringsSep " " cfg.rules;
        };

        systemd.services.zapret2 = {
          description = "zapret2 DPI bypass service";
          after = [ "network.target" ];
          wantedBy = [ "multi-user.target" ];

          serviceConfig = {
            ExecStart = "${cfg.package}/bin/nfqws2 @/etc/zapret2/${cfg.instance}.conf";
            Type = "notify";
            Restart = "on-failure";
            RestartSec = 5;
            AmbientCapabilities = [ "CAP_NET_ADMIN" "CAP_NET_RAW" ];
            DevicePolicy = "closed";
            KeyringMode = "private";
            LockPersonality = true;
            PrivateDevices = true;
            PrivateTmp = true;
            PrivateMounts = true;
            ProtectHome = true;
            ProtectHostname = true;
            ProtectClock = true;
            ProtectKernelLogs = true;
            ProtectKernelModules = true;
            ProtectKernelTunables = true;
            ProtectSystem = "strict";
            ProtectProc = "invisible";
            RemoveIPC = true;
            RestrictNamespaces = true;
            RestrictRealtime = true;
            RestrictSUIDSGID = true;
            SystemCallArchitectures = "native";
            UMask = "0077";
          };

          environment = {
            ZAPRET_BASE = "${cfg.package}/share/zapret2";
            ZAPRET_RW = "/etc/zapret2";
          };
        };
      }

      (mkIf cfg.configureFirewall {
        networking.firewall.extraCommands =
          let
            httpParams = optionalString (cfg.httpMode == "first")
              "-m connbytes --connbytes-dir=original --connbytes-mode=packets --connbytes 1:6";
          in
          ''
            ip46tables -t mangle -I POSTROUTING -p tcp --dport 443 -m connbytes --connbytes-dir=original --connbytes-mode=packets --connbytes 1:6 -m mark ! --mark 0x40000000/0x40000000 -j NFQUEUE --queue-num ${toString cfg.qnum} --queue-bypass
          ''
          + optionalString cfg.httpSupport ''
            ip46tables -t mangle -I POSTROUTING -p tcp --dport 80 ${httpParams} -m mark ! --mark 0x40000000/0x40000000 -j NFQUEUE --queue-num ${toString cfg.qnum} --queue-bypass
          ''
          + optionalString cfg.udpSupport ''
            ip46tables -t mangle -A POSTROUTING -p udp -m multiport --dports ${lib.concatStringsSep "," cfg.udpPorts} -m mark ! --mark 0x40000000/0x40000000 -j NFQUEUE --queue-num ${toString cfg.qnum} --queue-bypass
          '';
      })
    ]
  );

  meta.maintainers = with lib.maintainers; [ ];
}
