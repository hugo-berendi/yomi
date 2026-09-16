{
  lib,
  buildGoModule,
  fetchFromGitHub,
}:
buildGoModule (finalAttrs: {
  pname = "cliproxyapi-copilot-plugin";
  version = "0.3.3";

  src = fetchFromGitHub {
    owner = "arthur-sommer-etc";
    repo = "cliproxyapi-copilot-plugin";
    rev = "7f16b6011e93266f6d317166ef7cb6f0262f511f";
    hash = "sha256-9klfG6f73sU3c5cHE26HVkvlTObdxoQddQp6kM3nGFc=";
  };

  vendorHash = "sha256-0V5udhZKLg4kXoYVw7HFR/GsZmtOvHfajCC97Ku80m8=";

  # GitHub's Copilot /models response has no `supported_endpoints` field for
  # at least some accounts (confirmed live), so selectEndpoint() always finds
  # zero candidate endpoints and every model 422s with "Copilot model exposes
  # no supported chat endpoint". Fall back to the chat endpoint whenever
  # capabilities.type says "chat" and the upstream list came back empty.
  #
  # Separately, CLIProxyAPI's own /v1/chat/completions route reaches this
  # plugin's executor with an empty source format, which
  # normalizeRequestFormat() maps to "openai-response" (the Responses API).
  # That forces a response translation from plain OpenAI chat JSON into
  # Responses-API shape that silently produces an all-zero envelope instead
  # of erroring (confirmed live: HTTP 200, empty content, zeroed usage).
  # Requests actually arriving this way are plain OpenAI chat requests, so
  # default the empty case to "openai" (translator Format "openai", i.e. no
  # translation at all against the chat endpoint) instead.
  postPatch = ''
    substituteInPlace internal/provider/models.go --replace-fail \
      'endpoints := normalizeEndpoints(model.SupportedEndpoints)' \
      'endpoints := normalizeEndpoints(model.SupportedEndpoints)
    	if len(endpoints) == 0 && model.Capabilities.Type == "chat" {
    		endpoints = []string{translate.EndpointChatCompletions}
    	}'
    substituteInPlace internal/provider/executor.go --replace-fail \
      'case "", "responses", "openai-response", "openai-responses":
    		return "openai-response"' \
      'case "openai", "chat", "chat-completions":
    		return "openai"
    	case "", "responses", "openai-response", "openai-responses":
    		return "openai-response"'
    # The manifest only advertised "openai-response"/"claude" as executor
    # formats, so CLIProxyAPI's core force-translated every plain OpenAI
    # chat request into Responses-API shape before it ever reached this
    # plugin - and that openai-response<->openai bridge silently produces
    # an all-zero response for chat-endpoint models like gpt-4.1 (confirmed
    # live: HTTP 200, empty content, zeroed usage). Advertise "openai" too
    # so core leaves already-plain-chat requests untranslated.
    sed -i 's/\[\]string{"openai-response", "claude"}/[]string{"openai", "openai-response", "claude"}/g' \
      cmd/cliproxyapi-copilot/dispatch.go
    # Once formats match end to end (source == "openai", chat endpoint ==
    # "openai"), StreamFromEndpoint() takes an identity shortcut and relays
    # Copilot's raw SSE frames verbatim. Copilot's first streamed frame is a
    # content-filter preamble with an empty choices array and no delta;
    # opencode's strict OpenAI SSE client throws trying to parse it
    # (confirmed live: "JSON parsing failed" / "Unexpected identifier
    # data"). Drop empty-choices frames instead of forwarding them.
    substituteInPlace internal/translate/translate.go --replace-fail \
      'if from == to {
    		return [][]byte{append([]byte(nil), frame...)}, nil
    	}
    	return stream(ctx, from, to, model, original, translated, frame, state)
    }' \
      'if from == to {
    		payload, ok := sseDataPayload(frame)
    		if !ok || isEmptyChoicesJSON(payload) {
    			return nil, nil
    		}
    		return [][]byte{payload}, nil
    	}
    	return stream(ctx, from, to, model, original, translated, frame, state)
    }

    // internal/sse.Decoder only splits the upstream byte stream on blank-line
    // boundaries; it does not parse SSE fields. Its "frames" are raw blocks
    // like "data: {...}\n\n", still carrying the "data:" prefix core expects
    // callers to have already stripped (core adds its own "data: " framing
    // when writing the client-facing stream). Forwarding raw frames verbatim
    // through the identity path above doubled that prefix and broke every
    // opencode SSE parse (confirmed live: "Unexpected identifier data").
    func sseDataPayload(frame []byte) ([]byte, bool) {
    	var data []byte
    	for _, line := range bytes.Split(frame, []byte("\n")) {
    		line = bytes.TrimRight(line, "\r")
    		rest, isData := bytes.CutPrefix(line, []byte("data:"))
    		if !isData {
    			continue
    		}
    		data = append(data, bytes.TrimPrefix(rest, []byte(" "))...)
    	}
    	data = bytes.TrimSpace(data)
    	if len(data) == 0 || bytes.Equal(data, []byte("[DONE]")) {
    		return nil, false
    	}
    	return data, true
    }

    func isEmptyChoicesJSON(payload []byte) bool {
    	var probe struct {
    		Choices []json.RawMessage `json:"choices"`
    	}
    	if json.Unmarshal(payload, &probe) != nil {
    		return false
    	}
    	return len(probe.Choices) == 0
    }'
  '';

  env.CGO_ENABLED = 1;

  buildPhase = ''
    runHook preBuild
    go build -buildvcs=false -trimpath \
      -ldflags "-X main.pluginVersion=${finalAttrs.version}" \
      -buildmode=c-shared \
      -o cliproxyapi-copilot.so \
      ./cmd/cliproxyapi-copilot
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    install -Dm755 cliproxyapi-copilot.so $out/linux/amd64/cliproxyapi-copilot.so
    runHook postInstall
  '';

  doCheck = false;

  meta = {
    description = "GitHub Copilot subscription provider plugin for CLIProxyAPI";
    homepage = "https://github.com/arthur-sommer-etc/cliproxyapi-copilot-plugin";
    license = lib.licenses.mit;
    platforms = ["x86_64-linux" "aarch64-linux"];
    mainProgram = "cliproxyapi-copilot.so";
  };
})
