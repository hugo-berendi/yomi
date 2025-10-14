{
	config,
	pkgs,
	...
}: {
	# {{{ Reverse proxy
	yomi.nginx.at.paperless-ai.port = config.yomi.ports.paperless-ai;
	# }}}
	# {{{ Secrets
	sops.secrets.paperless_ai_env = {
		sopsFile = ../secrets.yaml;
	};
	# }}}
	# {{{ Service
	virtualisation.oci-containers.containers."paperless-ai" = {
		image = "clusterzx/paperless-ai:latest";
		environment = {
			PUID = "1000";
			PGID = "1000";
			PAPERLESS_AI_PORT = toString config.yomi.ports.paperless-ai;
			RAG_SERVICE_URL = "http://127.0.0.1:${toString config.yomi.ports.paperless-ai-rag}";
			RAG_SERVICE_ENABLED = "true";
		};
		environmentFiles = [config.sops.secrets.paperless_ai_env.path];
		volumes = [
			"paperless-ai_data:/app/data:rw"
		];
		ports = [
			"${toString config.yomi.ports.paperless-ai}:${toString config.yomi.ports.paperless-ai}/tcp"
		];
		log-driver = "journald";
		extraOptions = [
			"--network=host"
			"--cap-drop=ALL"
			"--security-opt=no-new-privileges=true"
		];
	};

	virtualisation.oci-containers.containers."paperless-ai-rag" = {
		image = "clusterzx/paperless-ai:rag";
		environment = {
			PUID = "1000";
			PGID = "1000";
			PORT = toString config.yomi.ports.paperless-ai-rag;
		};
		volumes = [
			"paperless-ai_rag:/app/data:rw"
		];
		ports = [
			"${toString config.yomi.ports.paperless-ai-rag}:${toString config.yomi.ports.paperless-ai-rag}/tcp"
		];
		log-driver = "journald";
		extraOptions = [
			"--cap-drop=ALL"
			"--security-opt=no-new-privileges=true"
		];
	};
	# }}}
}
