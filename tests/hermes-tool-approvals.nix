{pkgs}: let
  owner = "@owner:example.org";
  bot = "@ciel:example.org";
  grants.${owner}.${bot} = ["ciel_thread_open"];
  render = allowedUser: userId: toolApprovals:
    (import ../modules/nixos/hermes-dispatcher/dispatch.nix {
      inherit pkgs;
      inherit (pkgs) lib;
      config.yomi.hermesDispatcher = {
        inherit toolApprovals;
        matrix = {inherit allowedUser userId;};
      };
      inputs = {};
      state = "/unused";
      skills = {
        bundle = "/unused/skills";
        catalog = "/unused/catalog";
      };
      launcherSource = ../modules/nixos/hermes-dispatcher;
      routes = {};
    }).codexConfig;
in
  pkgs.runCommand "hermes-tool-approvals" {
    nativeBuildInputs = [pkgs.python3];
    selected = render owner bot grants;
    revoked = render owner bot {};
    otherOwner = render "@other:example.org" bot grants;
    otherBot = render owner "@otherbot:example.org" grants;
  } ''
    python3 - <<'PY'
    import os
    import tomllib

    for scenario in ("selected", "revoked", "otherOwner", "otherBot"):
        with open(os.environ[scenario], "rb") as stream:
            config = tomllib.load(stream)
        assert config["approval_policy"] == "on-request"
        assert set(config["mcp_servers"]) == {"ciel"}
        server = config["mcp_servers"]["ciel"]
        assert server["default_tools_approval_mode"] == "writes"
        tools = server.get("tools", {})
        expected = {"ciel_thread_open": {"approval_mode": "approve"}} if scenario == "selected" else {}
        assert tools == expected, (scenario, tools)
        assert "ciel_start_task" not in tools
    PY
    touch "$out"
  ''
