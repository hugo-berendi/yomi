{
  lib,
  stdenv,
  buildNpmPackage,
  fetchFromGitHub,
  nodejs_20, # works with upstream’s Node 20 lock-file
}:
buildNpmPackage rec {
  pname = "perplexica";
  version = "1.10.2"; # ⟵ see upstream package.json

  src = fetchFromGitHub {
    owner = "ItzCrazyKns";
    repo = "Perplexica";
    rev = "v${version}";
    # Run `nix flake prefetch github:ItzCrazyKns/Perplexica/v1.10.2`
    sha256 = "sha256-TbtP8KuDN+8a2QxHlXvTSUBmrrObLwc1FUlQxuXoWRs=";
  };

  npmDepsHash = "sha256-7DLyVUtW8JtV9oZslHzYkfsJYOwr6HvYg4X9U7I1M/8=";

  # Upstream’s “build” already runs the drizzle migration step
  postInstall = ''
    mkdir -p $out/bin
    cat > $out/bin/perplexica <<'EOF'
    #!${stdenv.shell}
    export NODE_ENV=production
    exec ${nodejs_20}/bin/node '${placeholder "out"}/lib/node_modules/perplexica/.next/standalone/server.js' "$@"
    EOF
    chmod +x $out/bin/perplexica
  '';
}
