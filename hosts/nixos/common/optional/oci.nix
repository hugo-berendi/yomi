{...}: {
  virtualisation.oci-containers.backend = "docker";

  # {{{ Persistence
  environment.persistence = {
    "/persist/state".directories = [
      "/var/lib/containers/storage"
    ];

    "/persist/local/cache".directories = [
      "/var/lib/containers/cache"
    ];
  };
  # }}}
}
