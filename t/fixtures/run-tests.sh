#!/bin/bash
set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Generate vault TLS certs
openssl req -x509 -newkey rsa:4096 -keyout /tmp/key.pem -out /tmp/cert.pem \
    -days 1 -nodes -subj '/CN=some.vault'
chmod 777 /tmp/key.pem /tmp/cert.pem

# Start infrastructure and run tests
export HOST_IP="$(hostname -I 2>/dev/null | awk '{print $1}' || echo '127.0.0.1')"
pushd "$SCRIPT_DIR"
docker compose --profile test up --build --abort-on-container-exit --exit-code-from test-runner
EXIT_CODE=$?
docker compose --profile test down
popd
exit $EXIT_CODE
