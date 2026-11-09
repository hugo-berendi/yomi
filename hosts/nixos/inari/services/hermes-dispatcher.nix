{config, ...}: let
  matrixHost = "matrix.${config.yomi.dns.domain}";
in {
  yomi.hermesDispatcher = {
    enable = true;
    t3.projectIds = [
      "d49c8ccb-3283-498d-90d8-41bd6131ac5d" # yomi
      "a86e9195-2e3d-4d59-a0a7-2935f3385508" # ai-skills
      "65cf1784-d9d6-4f83-8db0-5b6460c63757" # website-astro
      "c6fb85a6-cd0a-4076-845c-fa55bda57abf" # kasumi
      "a3d42413-b422-44d2-ae49-e8553019f94a" # hugo-berendi.de
      "199352e0-db7a-499b-8b7a-4eb20c66d833" # nixtop
      "f14f5f03-a6cb-4195-b4ad-aecbf42e6eb1" # leitenden-website
    ];
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
