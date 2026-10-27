# Example based cli docs
# https://dbrgn.github.io/tealdeer/
{config, ...}: {
  programs.tealdeer = {
    enable = true;
    # auto_update below already refreshes the cache on use; no timer needed.
    enableAutoUpdates = false;
    settings.updates.auto_update = true;
  };

  yomi.persistence.at.cache.apps.tealdeer.directories = [
    "${config.xdg.cacheHome}/tealdeer" # page cache
  ];
}
