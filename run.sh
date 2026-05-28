#!/bin/bash
# Usage: ./run.sh --storage <storage-dir> --mount <workdir> [--mount <workdir2> ...]

usage() {
  echo "Usage: ./run.sh --storage <storage-dir> --mount <workdir> [--mount <workdir2> ...]" >&2
}

STORAGE_DIR=""
WORKDIRS=()

while [ $# -gt 0 ]; do
  case "$1" in
    --storage)
      if [ $# -lt 2 ] || [ -z "$2" ]; then
        usage
        exit 1
      fi
      STORAGE_DIR="$2"
      shift 2
      ;;
    --mount)
      if [ $# -lt 2 ] || [ -z "$2" ]; then
        usage
        exit 1
      fi
      WORKDIRS+=("$2")
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      usage
      exit 1
      ;;
  esac
done

if [ -z "$STORAGE_DIR" ] || [ ${#WORKDIRS[@]} -eq 0 ]; then
  usage
  exit 1
fi

mkdir -p -- "$STORAGE_DIR"
STORAGE_DIR="$(cd -- "$STORAGE_DIR" && pwd)"

# Ensure persistent storage directories exist
mkdir -p "$STORAGE_DIR/.claude"
mkdir -p "$STORAGE_DIR/.codex"
mkdir -p "$STORAGE_DIR/.config/opencode"
mkdir -p "$STORAGE_DIR/.local/share/opencode"
mkdir -p "$STORAGE_DIR/.local/state/opencode"

# Build volume mounts for all provided directories
WORKDIR_MOUNTS=()
WORKDIR_TARGETS=()
for dir in "${WORKDIRS[@]}"; do
  abs=$(cd -- "$dir" && pwd)
  target="/home/agent/$(basename "$abs")"

  for existing_target in "${WORKDIR_TARGETS[@]}"; do
    if [ "$existing_target" = "$target" ]; then
      echo "Error: multiple workdirs map to $target. Use unique directory basenames."
      exit 1
    fi
  done

  WORKDIR_MOUNTS+=(-v "${abs}:${target}")
  WORKDIR_TARGETS+=("$target")
done

docker run -itd \
  --name agent-sandbox \
  --hostname sandbox \
  \
  `# Docker daemon access` \
  -v /var/run/docker.sock:/var/run/docker.sock \
  --group-add 0 \
  --group-add docker \
  \
  `# Working directories mounted under /home/agent by basename` \
  "${WORKDIR_MOUNTS[@]}" \
  \
  `# Persistent config and runtime data for Claude Code, Codex, and OpenCode` \
  -v "$STORAGE_DIR/.claude:/home/agent/.claude" \
  -v "$STORAGE_DIR/.codex:/home/agent/.codex" \
  -v "$STORAGE_DIR/.config/opencode:/home/agent/.config/opencode" \
  -v "$STORAGE_DIR/.local/share/opencode:/home/agent/.local/share/opencode" \
  -v "$STORAGE_DIR/.local/state/opencode:/home/agent/.local/state/opencode" \
  \
  ghcr.io/foralan/agent-sandbox:latest
