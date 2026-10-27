{upkgs}: {
  transparency = amount: {
    desktop = amount;
    applications = amount;
    terminal = amount;
    popups = amount;
  };

  base16 = name: "${upkgs.base16-schemes}/share/themes/${name}.yaml";
}
