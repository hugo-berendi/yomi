{
  config,
  lib,
  ...
}: let
  cfg = config.yomi.expose.server;
  inherit (cfg) protection;
  # No X-Forwarded-For depth: limits use the socket peer, so clients cannot
  # evade them by sending forged forwarding headers. Group IPv6 /64s together.
  clientIP.ipStrategy.ipv6Subnet = 64;
in {
  options.yomi.expose.server.protection = {
    enable = lib.mkEnableOption "HTTP flood limits on the gateway, in addition to the provider's network DDoS filter" // {default = true;};
    requestsPerSecond = lib.mkOption {
      type = lib.types.ints.positive;
      default = 50;
      description = "Sustained HTTP requests per second per source IP (IPv6 /64).";
    };
    burst = lib.mkOption {
      type = lib.types.ints.positive;
      default = 100;
      description = "Maximum HTTP request burst per source IP.";
    };
    concurrentPerIP = lib.mkOption {
      type = lib.types.ints.positive;
      default = 32;
      description = "Concurrent HTTP requests per source IP, including long-lived streams.";
    };
    concurrentPerHost = lib.mkOption {
      type = lib.types.ints.positive;
      default = 128;
      description = "Concurrent HTTP requests per hostname, including long-lived streams.";
    };
  };

  config = lib.mkIf (cfg.enable && protection.enable) {
    boot.kernel.sysctl."net.ipv4.tcp_syncookies" = 1;
    services.traefik = {
      staticConfigOptions.entryPoints.websecure = {
        forwardedHeaders.insecure = false;
        # Setting proxyProtocol at all enables its listener. Direct clients
        # need the regular TLS listener, with no trusted proxy addresses.
        # EntryPoint middleware also covers Pangolin's login/API routers and
        # runs before their authentication, without overriding generated routes.
        http.middlewares = [
          "expose-rate-limit@file"
          "expose-inflight-ip@file"
          "expose-inflight-host@file"
        ];
      };
      dynamicConfigOptions.http.middlewares = {
        expose-rate-limit.rateLimit = {
          average = protection.requestsPerSecond;
          inherit (protection) burst;
          period = "1s";
          sourceCriterion = clientIP;
        };
        expose-inflight-ip.inFlightReq = {
          amount = protection.concurrentPerIP;
          sourceCriterion = clientIP;
        };
        expose-inflight-host.inFlightReq = {
          amount = protection.concurrentPerHost;
          sourceCriterion.requestHost = true;
        };
      };
    };
  };
}
