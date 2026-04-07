#!/bin/bash
set -e

# Start redis instances
redis-server --daemonize yes
redis-server --port 6380 --requirepass passdefault --daemonize yes

# Forward localhost ports to docker compose services
socat TCP-LISTEN:8500,fork,reuseaddr TCP:consul:8500 &
socat TCP-LISTEN:8200,fork,reuseaddr TCP:vault:8200 &
socat TCP-LISTEN:8210,fork,reuseaddr TCP:vault:8210 &
socat TCP-LISTEN:2379,fork,reuseaddr TCP:etcd:2379 &
socat TCP-LISTEN:4001,fork,reuseaddr TCP:etcd:4001 &
socat TCP-LISTEN:14000,fork,reuseaddr TCP:pebble:14000 &
socat TCP-LISTEN:15000,fork,reuseaddr TCP:pebble:15000 &
socat TCP-LISTEN:8055,fork,reuseaddr TCP:challtestsrv:8055 &

# Wait for port forwarding to be ready
sleep 1

# Configure vault JWT auth
echo "Configuring vault JWT auth..."
curl -sk 'https://127.0.0.1:8210/v1/sys/auth/kubernetes.test' -X POST \
    -H 'X-Vault-Token: root' \
    -H 'Content-Type: application/json; charset=utf-8' \
    --data-raw '{"path":"kubernetes.test","type":"jwt","config":{}}'
curl -sk 'https://127.0.0.1:8210/v1/auth/kubernetes.test/config' -X PUT \
    -H 'X-Vault-Token: root' \
    -H 'content-type: application/json; charset=utf-8' \
    --data-raw '{"jwt_validation_pubkeys":["-----BEGIN PUBLIC KEY-----\nMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAtMCbmrsltFKqStOoxl8V\nK5ZlrIMb8d+W62yoXW1DKdg+cPNq0vGD94cxl9NjjRzlSR/NVZq6Q34c1lkbenPw\nf3CYfmbQupOKTJKhBdn9sFCCbW0gi6gQv0BaU3Pa8iGfVcZPctAtdbwmNKVd26hW\nmvnoJYhyewhY+j3ooLdnmh55cZU9w1VO0PaSf2zGSmCUeIao77jWcnkEauK2RrYv\nq5yB6w54Q71+lp2jZil9e4IJP/WqcS1CtmKgiWLoZuWNJXDWaa8LbcgQfsxudn3X\nsgHaYnAdZJOaCsDS/ablKmUOLIiI3TBM6dkUlBUMK9OgAsu+wBdX521rK3u+NNVX\n3wIDAQAB\n-----END PUBLIC KEY-----"],"default_role":"root","namespace_in_state":false,"provider_config":{}}'
curl -sk 'https://127.0.0.1:8210/v1/auth/kubernetes.test/role/root' -X POST \
    -H 'X-Vault-Token: root' \
    -H 'content-type: application/json; charset=utf-8' \
    --data-raw '{"token_policies":["acme"],"role_type":"jwt","user_claim":"kubernetes.io/serviceaccount/service-account.uid","bound_subject":"system:serviceaccount:kong:gateway-kong"}'
curl -sk 'https://127.0.0.1:8210/v1/sys/policies/acl/acme' -X PUT \
    -H 'X-Vault-Token: root' \
    -H 'Content-Type: application/json; charset=utf-8' \
    --data-raw '{"name":"acme","policy":"path \"secret/*\" {\n  capabilities = [\"create\", \"read\", \"update\", \"delete\"]\n}"}'

# Update challtestsrv to resolve domains to this container
MY_IP=$(hostname -I | awk '{print $1}')
curl -s --request POST --data '{"ip":"'"$MY_IP"'"}' http://127.0.0.1:8055/set-default-ipv4

echo "Running tests..."
exec prove -r t/
