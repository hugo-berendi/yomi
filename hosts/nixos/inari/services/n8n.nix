{config, ...}: {
  yomi.nginx.at.n8n.port = config.yomi.ports.n8n;

  services.n8n = {
    enable = true;
    webhookUrl = config.yomi.nginx.at.n8n.url;
    settings = {
      port = config.yomi.nginx.at.n8n.port;
      userManagement = {
        authenticationMethod = "email";
      };
      externalFrontendHooksUrls = "";
      sso = {
        justInTimeProvisioning = true;
        redirectLoginToSso = true;
        saml = {
          loginEnabled = false;
          loginLabel = "";
        };
        oidc = {
          loginEnabled = false;
        };
        ldap = {
          loginEnabled = false;
          loginLabel = "";
        };
      };
      redis = {
        prefix = "n8n";
      };
      endpoints = {
        rest = "";
      };
      ai = {
        enabled = false;
      };
    };
  };
}
