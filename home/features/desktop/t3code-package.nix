{
  inputs,
  pkgs,
  providerPackages,
}:
inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.t3code.override {
  inherit providerPackages;
}
