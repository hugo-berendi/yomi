{config, ...}: {
  # {{{ Ports
  yomi.ports = {
    qbittorrent_peer = 8518;
    qbittorrent_ui = 8516;
    qui = 8517;
  };
  # }}}
  # {{{ Reverse proxy
  # torrent.<domain> serves qui, the web UI in front of qBittorrent. qui runs
  # on the host and has its own login; qBittorrent's own WebUI only listens
  # inside the VPN namespace.
  yomi.nginx.at.torrent.port = config.yomi.ports.qui;
  # }}}
  # {{{ Settings
  nixarr.qbittorrent = {
    enable = true;
    vpn.enable = true;
    webuiPort = config.yomi.nginx.at.torrent.port;
    qui.internalPort = config.yomi.ports.qbittorrent_ui;
    # Mullvad forwards no ports, so this only matters for outgoing
    # connections; it is registered to keep it out of every other service's way.
    peerPort = config.yomi.ports.qbittorrent_peer;
    # Nixarr's queue caps active torrents at 10. Everything migrated from
    # Transmission is seeding, and a queued seed uploads nothing.
    torrentQueueing.enable = false;
  };

  # qBittorrent has no umask setting of its own, and the unit's default
  # leaves new files 0644. With fs.protected_hardlinks = 1, Radarr and Sonarr
  # may only hardlink a file they own or can write, so a 0644 download from
  # another user is silently copied instead. 0002 makes downloads writable by
  # the media group, which both are in.
  systemd.services.qbittorrent.serviceConfig.UMask = "0002";
  # }}}
  # {{{ *arr download clients
  # Upserted by name on every start of <arr>-sync-config. qBittorrent trusts
  # 192.168.15.0/24 (the VPN bridge) without a password, and the *arrs reach
  # it from the host side of that bridge.
  nixarr.radarr.settings-sync.downloadClients = [
    {
      name = "qBittorrent";
      implementation = "QBittorrent";
      fields = {
        host = "192.168.15.1";
        port = config.yomi.ports.qbittorrent_ui;
        movieCategory = "radarr";
      };
    }
  ];
  nixarr.sonarr.settings-sync.downloadClients = [
    {
      name = "qBittorrent";
      implementation = "QBittorrent";
      fields = {
        host = "192.168.15.1";
        port = config.yomi.ports.qbittorrent_ui;
        tvCategory = "sonarr";
      };
    }
  ];
  # }}}
}
