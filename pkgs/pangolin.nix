{
  fetchFromGitHub,
  fetchNpmDeps,
  fosrl-pangolin,
  edition,
}:
(fosrl-pangolin.override {inherit edition;}).overrideAttrs (final: _: {
  version = "1.27.0";
  src = fetchFromGitHub {
    owner = "fosrl";
    repo = "pangolin";
    tag = final.version;
    hash = "sha256-Z5roGPxH8xRpCKS3y8ct13wsMLoh9H6/0pYZjobvCYU=";
  };
  npmDeps = fetchNpmDeps {
    name = "${final.pname}-${final.version}-npm-deps";
    inherit (final) src;
    fetcherVersion = 2;
    hash = "sha256-seCi8vqvY/uYD3iVQx5FNxd9AsN6rLNl4ROZ3rbdT0U=";
  };
})
