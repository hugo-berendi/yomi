{
  config,
  pkgs,
  ...
}: let
  # {{{ Jupyterhub/lab env
  appEnv = pkgs.python3.withPackages (p:
    with p; [
      jupyterhub
      jupyterlab
      jupyterhub-systemdspawner
      jupyter-collaboration
      jupyterlab-git
    ]);
  # }}}
in {
  systemd.services.jupyterhub.path = [
    pkgs.texlive.combined.scheme-full # LaTeX stuff is useful for matplotlib
    pkgs.git # Required by the git extension
  ];

  services.jupyterhub = {
    enable = true;
    port = config.yomi.cloudflared.at.jupyter.port;

    jupyterhubEnv = appEnv;
    jupyterlabEnv = appEnv;

    # {{{ Spwaner & auth config
    extraConfig = ''
      c.Authenticator.allowed_users = {'hugob'}
      c.Authenticator.admin_users = {'hugob'}

      c.Spawner.notebook_dir='${config.users.users.pilot.home}/projects/notebooks'
      c.SystemdSpawner.mem_limit = '2G'
      c.SystemdSpawner.cpu_limit = 2.0
    '';
    # }}}
    # {{{ Python 3 kernel
    kernels.python3 = let
      env = pkgs.python3.withPackages (p:
        with p; [
          ipykernel
          numpy
          scipy
          matplotlib
          tabulate
        ]);
    in {
      displayName = "Numerical mathematics setup";
      argv = [
        "${env.interpreter}"
        "-m"
        "ipykernel_launcher"
        "-f"
        "{connection_file}"
      ];
      language = "python";
      logo32 = "${env}/${env.sitePackages}/ipykernel/resources/logo-32x32.png";
      logo64 = "${env}/${env.sitePackages}/ipykernel/resources/logo-64x64.png";
    };
    # }}}
  };

  # {{{ Networking & storage
  yomi.cloudflared.at.jupyter.port = config.yomi.ports.jupyterhub;

  environment.persistence."/persist/state".directories = [
    "/var/lib/${config.services.jupyterhub.stateDirectory}"
  ];
  # }}}
}
