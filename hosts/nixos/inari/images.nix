# Container image pins, one place so scripts/ci/update-docker-digests.sh has a single file to rewrite.
# Each reference is repo[:tag]@sha256:digest; the digest is what makes it reproducible.
{
  sockpuppetbrowser = "dgtlmoon/sockpuppetbrowser@sha256:1d8f72d2ce2085faed4232e5ae1e65c02efe5b831a18e127829b267c260b4fb2";
  changedetection = "ghcr.io/dgtlmoon/changedetection.io@sha256:096dae27b5d677b89f0e810fff95a70403271aa3ff3b6437952d2db9be7e74c5";
  sable = "ghcr.io/sableclient/sable@sha256:8f988d9e7a8ef5ed6b332677220110479e7f04e0b449a3ac820a251b39ade357";
  flaresolverr = "ghcr.io/flaresolverr/flaresolverr@sha256:c80ae007ce2ccdcd217a12426e4f039ef763ff90738c808d38810c3e59323767";
  paperless-ai = "clusterzx/paperless-ai@sha256:2b65888163fd59716f1c8285b31c5bd0b30c9c3c192c42b516688e3887d4ba60";
  pelican-panel = "ghcr.io/pelican/panel:v1.0.0-beta38@sha256:46f356f3fda423b1d43f0dc3c71efc056cd8b9bec365d1d7817306a17ee5694a";
  valheim = "ghcr.io/lloesche/valheim-server@sha256:c885aa902faf885ceb8f69a34663b90519e65aa65fbd9f893451f0640e218a4f";
  windrose = "indifferentbroccoli/windrose-server-docker@sha256:644cc3901250d14a10bcd58ffdfe7b88eb2cf6c7d6ff90d6ef01b8ce0dcfa51d";
}
