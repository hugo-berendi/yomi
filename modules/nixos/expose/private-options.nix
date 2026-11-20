{lib}: let
  inherit (lib) mkOption types;
in {
  enable = lib.mkEnableOption "this private resource" // {default = true;};
  mode = mkOption {
    type = types.enum ["host" "cidr" "http" "ssh" "inference" "exit-node"];
    default = "host";
    description = "Private Pangolin resource type. Use inference for an AI Gateway.";
  };
  destination = mkOption {
    type = types.nullOr types.nonEmptyStr;
    default = null;
    description = "Backend address, hostname or CIDR as seen by the site.";
  };
  destinationPort = mkOption {
    type = types.nullOr types.port;
    default = null;
    description = "Backend port for private HTTP or an existing SSH server. SSH defaults to 22.";
  };
  alias = mkOption {
    type = types.nullOr types.nonEmptyStr;
    default = null;
    description = "Private client DNS alias for a host or SSH resource.";
  };
  fullDomain = mkOption {
    type = types.nullOr (types.strMatching "[a-zA-Z0-9-]+(\\.[a-zA-Z0-9-]+)+");
    default = null;
    description = "Hostname on a domain managed by the Pangolin organization, used by private HTTP and AI Gateway resources. Configure the DNS required for Pangolin certificates separately.";
  };
  scheme = mkOption {
    type = types.nullOr (types.enum ["http" "https"]);
    default = null;
    description = "Scheme used by Newt to connect to a private HTTP backend. Defaults to HTTP.";
  };
  ssl = mkOption {
    type = types.nullOr types.bool;
    default = null;
    description = "Use TLS on the client-facing private HTTP or AI Gateway resource. Defaults to true.";
  };
  tcpPorts = mkOption {
    type = types.listOf types.port;
    default = [];
    description = "Allowed TCP ports for host, network or SSH resources. SSH defaults to its backend port; host and network resources default to none.";
  };
  udpPorts = mkOption {
    type = types.listOf types.port;
    default = [];
    description = "Allowed UDP ports for host or network resources. Defaults to none.";
  };
  allowICMP = lib.mkEnableOption "ICMP to this private host or network";
  labels = mkOption {
    type = types.listOf types.nonEmptyStr;
    default = [];
    description = "Pangolin resource labels.";
  };
  machines = mkOption {
    type = types.listOf types.nonEmptyStr;
    default = [];
    description = "Identifiers of Pangolin machine clients explicitly granted access.";
  };
  sites = mkOption {
    type = types.listOf types.nonEmptyStr;
    default = [];
    description = "Pangolin site identifiers. An empty list uses the site applying the blueprint.";
  };
  authDaemon = mkOption {
    default = {};
    description = "Private SSH authentication and auth daemon placement.";
    type = types.submodule {
      options = {
        mode = mkOption {
          type = types.enum ["site" "remote" "native"];
          default = "site";
          description = "Use an existing SSH server, a remote auth daemon, or Pangolin's native SSH on the site.";
        };
        pam = mkOption {
          type = types.enum ["passthrough" "push"];
          default = "passthrough";
          description = "Use the backend's existing credentials or provision accounts through Pangolin.";
        };
        port = mkOption {
          type = types.nullOr types.port;
          default = null;
          description = "Auth daemon port. Required for a remote auth daemon.";
        };
      };
    };
  };
  aiProviders = mkOption {
    default = [];
    description = "Existing organization AI providers attached to an inference resource. Use provider identifiers rather than API keys.";
    type = types.listOf (types.submodule {
      options = {
        provider = mkOption {
          type = types.nonEmptyStr;
          description = "Provider identifier in Pangolin.";
        };
        accessMode = mkOption {
          type = types.enum ["inherit" "select"];
          default = "inherit";
          description = "Inherit available models or limit the provider to selected models.";
        };
        models = mkOption {
          type = types.listOf types.nonEmptyStr;
          default = [];
          description = "Model identifiers for select mode.";
        };
        enable = lib.mkEnableOption "this AI provider attachment" // {default = true;};
      };
    });
  };
  aiBudgets = mkOption {
    default = [];
    description = "Token or cost budgets on an inference resource.";
    type = types.listOf (types.submodule {
      options = {
        amount = mkOption {
          type = types.addCheck types.number (amount: amount > 0);
          description = "Maximum usage in the configured unit and period.";
        };
        unit = mkOption {
          type = types.enum ["usd" "tokens"];
          description = "Budget unit.";
        };
        period = mkOption {
          type = types.enum ["hourly" "daily" "weekly" "monthly" "yearly" "lifetime"];
          default = "monthly";
          description = "Window for accumulating usage.";
        };
        enforcement = mkOption {
          type = types.enum ["hard" "soft"];
          default = "hard";
          description = "Block requests over budget or record overruns.";
        };
        enable = lib.mkEnableOption "this AI budget" // {default = true;};
      };
    });
  };
}
