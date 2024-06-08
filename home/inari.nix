{pkgs, ...}: {
  imports = [
    ./global.nix
  ];
  home = {
    username = "hugob";
    homeDirectory = "/home/hugob";
    stateVersion = "24.05"; # https://nixos.wiki/wiki/FAQ/When_do_I_update_stateVersion
    file = {};
    sessionVariables = {EDITOR = "nvim";};
    packages = with pkgs; [
      zoxide
      eza
      unstable.nerdfetch # for displaying pc/laptop stats
      unstable.alejandra # nix formatter
      unstable.neovim
    ];
  };
}
