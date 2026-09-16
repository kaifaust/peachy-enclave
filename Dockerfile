# syntax=docker/dockerfile:1.7
# ---------------------------------------------------------------------------
# peachy-egress-probe — a throwaway image that answers ONE question: what
# source IP does a Tinfoil Container present to the public internet, and does
# it change between requests or across a relaunch?
#
# Everything here is public on purpose. `egress-probe.sh` is byte-identical to
# deploy/tinfoil/egress-probe.sh in the private Peachy repo, which is where it
# is maintained; this copy exists because a Tinfoil config repo has to be
# public, and code that is already public may as well live beside the config
# it is measured with.
#
#   docker build -t egress-probe .
# ---------------------------------------------------------------------------

# alpine:3.22, multi-arch index digest as of 2026-09-16. busybox gives us the
# shell, `nc` (the HTTP server) and `wget` (the egress call); ca-certificates
# is the only thing added, because busybox wget verifies TLS against the
# system store and alpine ships no trust anchors by default.
FROM alpine:3.22@sha256:14358309a308569c32bdc37e2e0e9694be33a9d99e68afb0f5ff33cc1f695dce

RUN apk add --no-cache ca-certificates \
 && adduser -D -u 10001 probe

COPY egress-probe.sh /usr/local/bin/egress-probe
RUN chmod 0555 /usr/local/bin/egress-probe

USER probe
EXPOSE 8080

# No secrets, no env, no state. /tmp holds one file (the boot timestamp) and
# tinfoil-config.yml mounts a tmpfs there, since an enclave's root filesystem
# is read-only.
ENTRYPOINT ["/usr/local/bin/egress-probe"]
CMD ["serve"]
