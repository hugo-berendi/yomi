# Azure AI Foundry resource shared by the claude-foundry launcher and
# opencode's provider block. The key stays out of the store: both read it
# from this file at run time, relative to the home directory.
{
  resource = "website-astro-ai-resource";
  keyFile = ".claude/foundry-api-key";
}
