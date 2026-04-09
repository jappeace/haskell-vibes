#! /usr/bin/env bash

set -xe

# Ensure an instance name is provided as the first argument
if [ -z "$1" ]; then
    echo "Error: Instance name required."
    echo "Usage: $0 <instance_name>"
    exit 1
fi

INSTANCE_NAME="$1"

mkdir -p ../vibes/$INSTANCE_NAME

# make sure they got their little claude state and memories
INSTANCE_DIR="$(pwd)/instances/$INSTANCE_NAME"
INSTANCE_JSON="$(pwd)/instances/${INSTANCE_NAME}.json"

if [ ! -d "$INSTANCE_DIR" ]; then
    echo "Creating instance directory: $INSTANCE_DIR"
    mkdir -p "$INSTANCE_DIR"
fi

if [ -e "$INSTANCE_JSON" ] && [ ! -f "$INSTANCE_JSON" ]; then
    echo "Warning: $INSTANCE_JSON exists but is not a regular file. Deleting..."
    rm -rf "$INSTANCE_JSON"
fi

if [ ! -f "$INSTANCE_JSON" ]; then
    echo "Creating empty JSON config: $INSTANCE_JSON"
    echo "{}" > "$INSTANCE_JSON"
fi

# Map instance name to voice model name
case "$INSTANCE_NAME" in
  stan)  VOICE_NAME="joe" ;;
  cabal) VOICE_NAME="cabal" ;;
  morag) VOICE_NAME="morag" ;;
  *)     VOICE_NAME="amy" ;;
esac

# we got to build it's jail.
OS_NAME=$(uname -s)
DOCKER_PLATFORM_ARGS=()
NIX_ARGS="./default.nix --arg uid $(id -u) --arg gid $(id -g) --argstr voiceName $VOICE_NAME"

if [ "$OS_NAME" != "Darwin" ]; then
    # on linux we can do this normally
    # build all things first, all paths are available on the host
    nix-build $NIX_ARGS
    # 1A. Linux Native: Build and load normally
    docker load -i "$(nix-build $NIX_ARGS -A image)"

else
    # osx we've to build for linux, to do that we borrow dockers' running linux

    # 1B. macOS: Build inside a Linux Nix container to bypass missing features
    ARCH=$(uname -m)

    if [ "$ARCH" == "arm64" ]; then
        # Apple Silicon Mac
        DOCKER_PLATFORM_ARGS=("--platform" "linux/arm64")
        docker run --rm \
            -v nix-builder-cache:/nix \
            -v "$(pwd):/workspace" -w /workspace nixos/nix \
            sh -c 'nix-build $NIX_ARGS -A image > /dev/null && cat result' | docker load
    else
        # Intel Mac
        DOCKER_PLATFORM_ARGS=("--platform" "linux/amd64")
        docker run --platform linux/amd64 --rm \
               -v nix-builder-cache:/nix \
               -v "$(pwd):/workspace" -w /workspace nixos/nix \
            sh -c 'nix-build $NIX_ARGS -A image > /dev/null && cat result' | docker load
    fi
fi


# Run the container
docker run -it \
    --name "$INSTANCE_NAME" \
    --hostname "$INSTANCE_NAME" \
    "${DOCKER_PLATFORM_ARGS[@]}" \
    --tmpfs /tmp:rw,exec,mode=1777 \
    --init \
    --dns 8.8.8.8 \
    --add-host=host.docker.internal:host-gateway \
    -e NODE_OPTIONS="--dns-result-order=ipv4first" \
    -e INSTANCE_NAME="$INSTANCE_NAME" \
    -e TERM=xterm-256color \
    -e COLORTERM=truecolor \
    -e GH_TOKEN="$(cat ~/.gh_token)" \
    -e HOME="/home/claude" \
    -e CLAUDE_UID="$(id -u)" \
    -e CLAUDE_GID="$(id -g)" \
    --ulimit nofile=1048576:1048576 \
    --ulimit nproc=65535:65535 \
    -v "$HOME/.ssh/sloth:/home/claude/.ssh/id_ed25519" \
    -v "$HOME/.ssh/sloth:/tmp/builder_key:ro" \
    -v "$(pwd)/instances/${INSTANCE_NAME}.json":/home/claude/.claude.json \
    -v "$(pwd)/instances/${INSTANCE_NAME}":/home/claude/.claude \
    -v "$(pwd)/settings.json":/home/claude/.claude/settings.json \
    -v "$(pwd)/CLAUDE.md":/home/claude/.claude/CLAUDE.md \
    -v "/run/user/$(id -u)/pulse:/run/user/1000/pulse" \
    -e PULSE_SERVER="unix:/run/user/1000/pulse/native" \
    -v "$(pwd)/../vibes/$INSTANCE_NAME":/home/claude/vibes \
    -v "$(pwd)/skills":/home/claude/.claude/skills \
    -v "$(pwd)/character":/home/claude/character \
    -v "$(pwd)/hooks":/home/claude/.claude/hooks \
    --rm \
    claude-env:latest \
    claude
