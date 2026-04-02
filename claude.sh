#! /usr/bin/env bash

set -xe

# Ensure an instance name is provided as the first argument
if [ -z "$1" ]; then
    echo "Error: Instance name required."
    echo "Usage: $0 <instance_name>"
    exit 1
fi

INSTANCE_NAME="$1"

nix-build default.nix

# 1. Build and load the Docker image via Nix
# nix-build creates an executable script that streams the image tarball; we pipe it to docker load.
docker load -i "$(nix-build default.nix -A image)"

# 2. Run the container
docker run -it \
    --tmpfs /tmp:rw,exec,mode=1777 \
    --init \
    --dns 8.8.8.8 \
    -e NODE_OPTIONS="--dns-result-order=ipv4first" \
    -e INSTANCE_NAME=$INSTANCE_NAME \
    -e TERM=xterm-256color \
    -e COLORTERM=truecolor \
    -e GH_TOKEN="$(cat ~/.gh_token)" \
    -e HOME="/home/claude" \
    -e NIX_REMOTE=daemon \
    --user "$(id -u):$(id -g)" \
    -v /nix/var/nix/daemon-socket/socket:/nix/var/nix/daemon-socket/socket \
    -v /nix/store:/nix/store:ro \
    -v "$HOME/.ssh/sloth:/home/claude/.ssh/id_ed25519" \
    -v "$(pwd)/instances/${INSTANCE_NAME}.json":/home/claude/.claude.json \
    -v "$(pwd)/instances/${INSTANCE_NAME}":/home/claude/.claude \
    -v "$(pwd)/settings.json":/home/claude/.claude/settings.json \
    -v "$(pwd)/CLAUDE.md":/home/claude/.claude/CLAUDE.md \
    -v "/run/user/$(id -u)/pulse:/run/user/1000/pulse" \
    -e PULSE_SERVER="unix:/run/user/1000/pulse/native" \
    -v "$(pwd)/../vibes":/home/claude/vibes \
    -v "$(pwd)/skills":/home/claude/.claude/skills \
    -v "$(pwd)/character":/home/claude/character \
    -v "$(pwd)/hooks":/home/claude/.claude/hooks \
    --rm \
    claude-env:latest \
    claude
