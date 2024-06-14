{pkgs, ...}:
pkgs.mkShell {
  pacakges = with pkgs; [
    biome
    bun
    nodejs
    typescript
  ];
}
