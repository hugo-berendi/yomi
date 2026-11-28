{config, ...}: let
  issuer = config.yomi.web.at.pocket-id.url;
  credentials = config.sops.secrets;
in {
  sops.secrets = {
    grafana_oidc_client_id = {
      sopsFile = ./secrets.yaml;
      owner = "grafana";
    };
    grafana_oidc_client_secret = {
      sopsFile = ./secrets.yaml;
      owner = "grafana";
    };
  };

  services.grafana.settings = {
    security.cookie_secure = true;
    "auth.generic_oauth" = {
      enabled = true;
      name = "Yomi SSO";
      allow_sign_up = true;
      auto_login = false;
      client_id = "$__file{${credentials.grafana_oidc_client_id.path}}";
      client_secret = "$__file{${credentials.grafana_oidc_client_secret.path}}";
      scopes = "openid profile email";
      auth_url = "${issuer}/authorize";
      token_url = "${issuer}/api/oidc/token";
      api_url = "${issuer}/api/oidc/userinfo";
      use_pkce = true;
      validate_id_token = true;
      jwk_set_url = "${issuer}/.well-known/jwks.json";
      role_attribute_strict = true;
      role_attribute_path = "sub == '0c0fcbd2-0e58-4171-af29-d9d6d361c087' && 'Admin'";
    };
  };
}
