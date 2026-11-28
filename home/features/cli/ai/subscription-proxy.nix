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
    probe = ''
      key_file="$HOME/${keyFile}"
      key=""
      proxy_get() {
        printf 'Authorization: Bearer %s\n' "$key" |
          ${pkgs.curl}/bin/curl -fsS -m 2 -H @- "${url}/v1/models$1" 2>/dev/null
      }
      if [[ -z "''${CLIPROXYAPI_DISABLE:-}" && -r "$key_file" ]]; then
        key="$(<"$key_file")"
        if ! inventory="$(proxy_get "")"; then
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
          if settings="$(printf '%s' "$inventory" | ${pkgs.jq}/bin/jq -ce '
            {availableModels: ([.data[] | select(.owned_by == "anthropic") | .id] | unique)}
            | select(.availableModels | length > 0)
          ')"; then
            export ANTHROPIC_BASE_URL="${url}" ANTHROPIC_AUTH_TOKEN="$key"
            exec ${pkg}/bin/claude --settings "$settings" "$@"
          fi
        fi
        exec ${pkg}/bin/claude "$@"
      '';
    # Codex keeps sending its own ChatGPT login, which the proxy ignores; the
    # proxy accepts its key from X-Api-Key alongside it
    # (internal/access/config_access/provider.go).
    codex = pkg:
      wrapBin pkg "codex" ''
        if [[ -n "$key" ]]; then
          version="$(${pkg}/bin/codex --version)"
          version="''${version##* }"
          if catalog="$(proxy_get "?client_version=$version" | ${pkgs.jq}/bin/jq -ce --argjson inventory "$inventory" '
            ($inventory.data | map(select(.owned_by == "openai") | .id)) as $allowed
            | .models |= map(select(.slug as $id | $allowed | index($id)))
            | select(.models | length > 0)
          ')"; then
            cache_dir="''${XDG_CACHE_HOME:-$HOME/.cache}/cliproxyapi"
            umask 077
            mkdir -p "$cache_dir" || exit 1
            catalog_file="$(mktemp "$cache_dir/codex.XXXXXX")" || exit 1
            printf '%s\n' "$catalog" > "$catalog_file" || exit 1
            mv -f -- "$catalog_file" "$cache_dir/codex-models.json" || exit 1
            catalog_config="$(printf '%s' "$cache_dir/codex-models.json" | ${pkgs.jq}/bin/jq -Rs .)"
            export CLIPROXYAPI_KEY="$key"
            exec ${pkg}/bin/codex \
              -c "model_catalog_json=$catalog_config" \
              -c model_provider=cliproxyapi \
              -c 'model_providers.cliproxyapi={name="OpenAI",base_url="${url}/v1",wire_api="responses",requires_openai_auth=true,supports_websockets=true,env_http_headers={"X-Api-Key"="CLIPROXYAPI_KEY"}}' \
              "$@"
          fi
        fi
        exec ${pkg}/bin/codex "$@"
      '';
  };
}
