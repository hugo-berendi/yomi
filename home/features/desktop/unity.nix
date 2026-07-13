{
  pkgs,
  config,
  ...
}: {
  home.packages = [
    pkgs.dotnet-sdk
  ];

  yomi.persistence.at.state.apps.unity.directories = [
    "${config.home.homeDirectory}/Unity"
    "${config.home.homeDirectory}/.config/unity3d/"
  ];
}
