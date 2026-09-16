# peachy-enclave

Public Tinfoil Container configuration for [Peachy](https://pchy.app).

Tinfoil measures `tinfoil-config.yml` at a **tag of a public GitHub repo** and
publishes the measurement to the Sigstore transparency log, so a client can
check that the enclave it is talking to is running the configuration published
here. That is why this repo exists and why it is public: the Peachy repo is
private, and a private config could not be audited by anyone.

Everything in this repo is public by construction — the resource shape, the
egress allowlist, the names (never the values) of secrets, and the image
digest.

## Layout

| Path | What it is |
|---|---|
| `tinfoil-config.yml` | The configuration measured at the tag being deployed. One config per release tag; the tag decides which workload this repo describes. |
| `Dockerfile`, `egress-probe.sh` | The egress probe — a ~10 MB alpine image whose only job is to report the source IP an enclave presents to the internet. Public code, so it lives beside the config it is measured with. |
| `.github/workflows/probe-image.yml` | Builds and pushes `ghcr.io/kaifaust/peachy-egress-probe`. |
| `.github/workflows/tinfoil-release.yml` | Tags a release. Verbatim from `tinfoilsh/tinfoil-containers-template`. |
| `.github/workflows/tinfoil-release-publish.yml` | Measures the config, signs it into Sigstore and cuts the GitHub release carrying `tinfoil-deployment.json`. Verbatim from the same template. |

## Releasing

```sh
gh workflow run probe-image.yml -f version=probe-v0.0.1   # note the digest
# pin the digest in tinfoil-config.yml, commit
gh workflow run tinfoil-release.yml -f version=probe-v0.0.1
```

Then deploy the tag:

```sh
tinfoil container create peachy-egress-probe \
  --repo kaifaust/peachy-enclave --tag probe-v0.0.1
```

## Tags

| Tag | Workload |
|---|---|
| `probe-v0.0.1` | Egress probe. Deployed and deleted on 2026-09-16 to measure enclave egress source IPs. |
