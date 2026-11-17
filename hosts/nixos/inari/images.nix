# Container image pins, one place so scripts/ci/update-docker-digests.sh has a single file to rewrite.
# Each reference is repo[:tag]@sha256:digest; the digest is what makes it reproducible.
{
  sockpuppetbrowser = "dgtlmoon/sockpuppetbrowser@sha256:1d8f72d2ce2085faed4232e5ae1e65c02efe5b831a18e127829b267c260b4fb2";
  changedetection = "ghcr.io/dgtlmoon/changedetection.io@sha256:096dae27b5d677b89f0e810fff95a70403271aa3ff3b6437952d2db9be7e74c5";
  sable = "ghcr.io/sableclient/sable-next:dev@sha256:33ed7971c4f92989d61ae0f063d4e121f9276b07c0aa5e69d8a164462122e4fd";
  flaresolverr = "ghcr.io/flaresolverr/flaresolverr@sha256:c80ae007ce2ccdcd217a12426e4f039ef763ff90738c808d38810c3e59323767";
  pelican-panel = "ghcr.io/pelican/panel:v1.0.0-beta38@sha256:46f356f3fda423b1d43f0dc3c71efc056cd8b9bec365d1d7817306a17ee5694a";
  valheim = "ghcr.io/lloesche/valheim-server@sha256:c885aa902faf885ceb8f69a34663b90519e65aa65fbd9f893451f0640e218a4f";
  windrose = "indifferentbroccoli/windrose-server-docker@sha256:644cc3901250d14a10bcd58ffdfe7b88eb2cf6c7d6ff90d6ef01b8ce0dcfa51d";
  audiomuse = "ghcr.io/neptunehub/audiomuse-ai:3.7.2@sha256:e4d28b44eee120a5fc0663022a5cdfc78e8056be7ff6a73441e5bc79ededec1c";
  # AudioMuse-AI is built against PostgreSQL 15.
  audiomuse-postgres = "postgres:15-alpine@sha256:23799e521dee9265a8b388ecf3bc0f1eaa34b95be67f5a76af4f8f6adb44c720";
}
