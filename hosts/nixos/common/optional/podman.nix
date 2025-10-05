{...}: {
  # {{{ Virtualization
  virtualisation = {
    podman = {
      enable = true;
      dockerCompat = true;
    };

    oci-containers.backend = "podman";
  };
  # }}}
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
