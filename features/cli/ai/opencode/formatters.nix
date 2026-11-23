{
  pkgs,
  lib,
  ...
}: {
  programs.opencode.settings = {
    # {{{ Formatter Configuration
    formatter = {
      alejandra = {
        command = ["${lib.getExe pkgs.alejandra}" "$FILE"];
        extensions = [".nix"];
      };
      stylua = {
        command = ["${lib.getExe pkgs.stylua}" "$FILE"];
        extensions = [".lua"];
      };
      prettierd = {
        command = ["${lib.getExe pkgs.prettierd}" "$FILE"];
        extensions = [".js" ".jsx" ".ts" ".tsx" ".astro" ".css" ".scss" ".html" ".md" ".mdx" ".graphql"];
      };
      biome = {
        command = ["${lib.getExe pkgs.biome}" "format" "--write" "$FILE"];
        extensions = [".json" ".jsonc"];
      };
      ruff = {
        command = ["${lib.getExe pkgs.ruff}" "format" "$FILE"];
        extensions = [".py" ".pyi"];
      };
      rustfmt = {
        command = ["${lib.getExe pkgs.rustfmt}" "$FILE"];
        extensions = [".rs"];
      };
      gofumpt = {
        command = ["${lib.getExe pkgs.gofumpt}" "-w" "$FILE"];
        extensions = [".go"];
      };
      yamlfmt = {
        command = ["${lib.getExe pkgs.yamlfmt}" "$FILE"];
        extensions = [".yaml" ".yml"];
      };
      taplo = {
        command = ["${lib.getExe pkgs.taplo}" "format" "$FILE"];
        extensions = [".toml"];
      };
      shfmt = {
        command = ["${lib.getExe pkgs.shfmt}" "-w" "$FILE"];
        extensions = [".sh" ".bash"];
      };
    };
    # }}}
  };
}
