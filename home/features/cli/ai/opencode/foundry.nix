{config, ...}: let
  foundry = import ../foundry.nix;
in {
  programs.opencode.settings.provider.foundry = {
    # {{{ Azure AI Foundry - non-Anthropic deployments
    # T3 Code has no Foundry driver of its own; its OpenCode provider lists
    # every model this opencode instance knows, so these show up there as
    # foundry/<deployment>. Claude deployments go through claude-foundry.
    npm = "@ai-sdk/openai-compatible";
    name = "Azure AI Foundry";
    options = {
      baseURL = "https://${foundry.resource}.services.ai.azure.com/openai/v1";
      # Resolved when opencode loads its config. A host without the file
      # still starts; only calls to these models fail.
      apiKey = "{file:${config.home.homeDirectory}/${foundry.keyFile}}";
    };
    # Keys are Foundry deployment names, not catalog model ids. List them with
    #   curl -H "api-key: $(cat ~/.claude/foundry-api-key)" \
    #     'https://<resource>.services.ai.azure.com/openai/deployments?api-version=2022-12-01'
    models = {
      "Kimi-K3.1-Pro" = {
        name = "Kimi K3.1 Pro";
        tool_call = true;
        reasoning = true;
      };
    };
    # }}}
  };
}
