{importall, ...}: let
  # Function to recursively import .nix files
  importNixFilesRec = path:
    builtins.foldl'
    (allFiles: currentFile:
      if builtins.pathExists currentFile && builtins.match ".*\\.nix$" currentFile
      then (allFiles ++ [(import currentFile)])
      else if builtins.isDirectory currentFile
      then (allFiles ++ (importNixFilesRec currentFile))
      else allFiles)
    []
    (builtins.readDir path);
in {
  importNixFilesRec .

  programs.nixvim = {
    colorschemes.rose-pine = {
      enable = true;
    };
  };
}
