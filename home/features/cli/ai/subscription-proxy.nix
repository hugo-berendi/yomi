# Routes Claude Code and Codex through CLIProxyAPI on inari, which holds the
# pilot's Claude and ChatGPT subscription logins and spends the extra accounts
# before the main ones (hosts/nixos/inari/services/cliproxyapi).
#
# The wrappers fall back to the binary's own login when this machine has no
# key file or the proxy does not answer within two seconds, so a laptop away
# from NetBird still works. CLIPROXYAPI_DISABLE=1 forces the direct path.
let
  port = 8502;
  # NetBird peers get a route to this one address (services/netbird.nix), so
  # the same URL works at home, over NetBird and on inari itself.
  url = "http://${(import ../../../../profiles/inventory.nix).inari.ipv4}:${toString port}";
  keyFile = ".config/cliproxyapi/api-key";
in {
  inherit port url keyFile;

  wrap = pkgs: let
    # Prints the key when the proxy accepts it, nothing otherwise.
    probe = ''
      key_file="$HOME/${keyFile}"
      key=""
      if [[ -z "''${CLIPROXYAPI_DISABLE:-}" && -r "$key_file" ]]; then
        key="$(<"$key_file")"
        if ! ${pkgs.curl}/bin/curl -fsS -m 2 -o /dev/null -H "Authorization: Bearer $key" "${url}/v1/models" 2>/dev/null; then
          key=""
        fi
      fi
    '';
    wrapBin = pkg: bin: script:
      pkgs.symlinkJoin {
        name = "${pkg.name}-cliproxyapi";
        paths = [pkg];
        inherit (pkg) meta;
        postBuild = ''
          rm "$out/bin/${bin}"
          cat > "$out/bin/${bin}" <<'EOF'
          #!${pkgs.runtimeShell}
          ${probe}
          ${script}
          EOF
          chmod +x "$out/bin/${bin}"
        '';
      };
  in {
    claude = pkg:
      wrapBin pkg "claude" ''
        if [[ -n "$key" && -z "''${ANTHROPIC_BASE_URL:-}" ]]; then
          export ANTHROPIC_BASE_URL="${url}" ANTHROPIC_AUTH_TOKEN="$key"
        fi
        exec ${pkg}/bin/claude "$@"
      '';
    # Codex keeps sending its own ChatGPT login, which the proxy ignores; the
    # proxy accepts its key from X-Api-Key alongside it
    # (internal/access/config_access/provider.go).
    codex = pkg:
      wrapBin pkg "codex" ''
        if [[ -n "$key" ]]; then
          export CLIPROXYAPI_KEY="$key"
          exec ${pkg}/bin/codex \
            -c model_provider=cliproxyapi \
            -c 'model_providers.cliproxyapi={name="OpenAI",base_url="${url}/v1",wire_api="responses",requires_openai_auth=true,supports_websockets=true,env_http_headers={"X-Api-Key"="CLIPROXYAPI_KEY"}}' \
            "$@"
        fi
        exec ${pkg}/bin/codex "$@"
      '';
  };
}
