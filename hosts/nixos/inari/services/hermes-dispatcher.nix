{config, ...}: let
  matrixHost = "matrix.${config.yomi.dns.domain}";
in {
  yomi.hermesDispatcher = {
    enable = true;
    matrix = {
      homeserver = "http://127.0.0.1:${toString config.yomi.ports.matrix-tuwunel}";
      userId = "@ciel:${matrixHost}";
      displayName = "Ciel";
      allowedUser = "@kamachi:${matrixHost}";
      registrationTokenFile = config.sops.secrets.matrix_tuwunel_registration_token.path;
    };
  };
  systemd.services.hermes-matrix-bootstrap = {
    requires = ["tuwunel.service"];
    after = ["tuwunel.service" "sops-nix.service"];
  };
}
