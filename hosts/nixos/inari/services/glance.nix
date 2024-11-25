{config, ...}: {
  yomi.cloudflared.at.news.port = config.yomi.ports.glance;
  services.glance = {
    enable = true;
    settings = {
      server.port = config.yomi.ports.glance;
      pages = [
        {
          name = "Home";
          columns = [
            {
              size = "small";
              widgets = [
                {
                  type = "calendar";
                }
                {
                  type = "rss";
                  limit = 10;
                  collapse-after = 3;
                  cache = "3h";
                  feeds = [
                    {
                      url = "https://selfh.st/rss/";
                      title = "selfh.st";
                    }
                  ];
                }
                {
                  type = "twitch-channels";
                  channels = [
                    "theprimeagen"
                    "cohhcarnage"
                    "christitustech"
                    "blurbs"
                    "asmongold"
                    "jembawls"
                  ];
                }
              ];
            }
            {
              size = "full";
            }
            {
              size = "small";
            }
          ];
        }
      ];
    };
  };
}
