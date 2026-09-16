#!/bin/sh
# ---------------------------------------------------------------------------
# The whole of the egress probe. No Peachy code, no dependencies beyond
# busybox: this image exists to answer one question — what source IP does a
# Tinfoil Container present to the public internet, and is it stable? — from
# inside an enclave, so the less of it there is, the less there is to argue
# about. See docs/tinfoil-container.md §Measured egress.
#
# Two modes. `serve` is PID 1's loop; `handle` is what busybox nc runs per
# connection with the socket on stdin/stdout, so the HTTP parsing below reads
# the request straight off stdin and writes the response straight to stdout.
# ---------------------------------------------------------------------------
set -eu

PORT="${PORT:-8080}"
BOOT_FILE=/tmp/boot-time

# `wget -T` rather than an unbounded fetch: a blocked egress host under an
# allowlist hangs on connect rather than refusing, and a probe that never
# answers looks identical to a probe that crashed.
FETCH_TIMEOUT="${FETCH_TIMEOUT:-10}"

now() { date -u +%Y-%m-%dT%H:%M:%SZ; }

# Echo the response with an explicit Content-Length and Connection: close.
# Keep-alive would mean parsing a second request off the same socket, and
# nothing here is worth that.
respond() {
	status="$1"
	body="$2"
	printf 'HTTP/1.1 %s\r\n' "$status"
	printf 'Content-Type: text/plain; charset=utf-8\r\n'
	printf 'Content-Length: %s\r\n' "$(printf '%s' "$body" | wc -c)"
	printf 'Cache-Control: no-store\r\n'
	printf 'Connection: close\r\n'
	printf '\r\n'
	printf '%s' "$body"
}

# One line of `<label>=<value>`, with a visible marker rather than an empty
# string when the fetch fails — "the allowlist blocked it" and "the service
# returned nothing" must not look the same in the transcript.
probe_host() {
	label="$1"
	url="$2"
	value="$(wget -q -T "$FETCH_TIMEOUT" -O - "$url" 2>/dev/null || true)"
	[ -n "$value" ] || value="FETCH-FAILED"
	printf '%s=%s\n' "$label" "$value"
}

case "${1:-serve}" in
serve)
	now >"$BOOT_FILE"
	# -lk keeps listening after each connection; -e hands the socket to this
	# same script. busybox forks per connection, so the ~1s of wget in /ip
	# does not stall a concurrent health check.
	exec nc -lk -p "$PORT" -e "$0" handle
	;;
handle)
	# Request line, then drain headers to the blank line. Answering before
	# the client has finished sending would race a connection reset.
	read -r _method path _proto || exit 0
	cr="$(printf '\r')"
	while IFS= read -r line; do
		line="${line%$cr}"
		[ -n "$line" ] || break
	done

	case "${path%%\?*}" in
	/healthz)
		respond '200 OK' 'ok'
		;;
	/ip)
		body="$(
			probe_host ipv4 https://api.ipify.org
			probe_host ipv46 https://api64.ipify.org
			probe_host aws https://checkip.amazonaws.com
			printf 'hostname=%s\n' "$(hostname)"
			printf 'boot=%s\n' "$(cat "$BOOT_FILE" 2>/dev/null || echo unknown)"
			printf 'now=%s\n' "$(now)"
		)"
		respond '200 OK' "$body"
		;;
	*)
		respond '404 Not Found' 'not found'
		;;
	esac
	;;
*)
	echo "usage: $0 [serve|handle]" >&2
	exit 64
	;;
esac
