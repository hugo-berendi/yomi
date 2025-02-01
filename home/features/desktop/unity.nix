{
  pkgs,
  config,
  ...
}: {
  home.packages = [
    pkgs.unityhub
    pkgs.dotnet-sdk
  ];

  yomi.persistence.at.state.apps.unity.directories = ["${config.home.homeDirectory}/Unity"];
}
