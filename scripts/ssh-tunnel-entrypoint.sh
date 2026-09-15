#!/bin/sh
set -eu

install -m 600 /run/secrets/codex_gateway_ed25519 /tmp/codex_gateway_ed25519
exec ssh -i /tmp/codex_gateway_ed25519 "$@"
