#!/bin/bash
# Usage: ./run.sh [path/to/workdir]
# If no argument given, mounts the current directory.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
STORAGE_DIR="$SCRIPT_DIR/storage"

# At least one working directory is required
if [ $# -eq 0 ]; then
  echo "Usage: ./run.sh <workdir> [workdir2 ...]"
  exit 1
fi

# Ensure persistent storage directories exist
mkdir -p "$STORAGE_DIR/.claude"
mkdir -p "$STORAGE_DIR/.codex"
mkdir -p "$STORAGE_DIR/.config/opencode"
mkdir -p "$STORAGE_DIR/.local/share/opencode"

# Build volume mounts for all provided directories
WORKDIR_MOUNTS=()
for dir in "$@"; do
  abs=$(cd "$dir" && pwd)
  WORKDIR_MOUNTS+=(-v "${abs}:${abs}")
done

# First directory becomes the container's working directory
PRIMARY_WORKDIR=$(cd "$1" && pwd)

# Generate runtime info file (regenerated every run) — mounted read-only at
# /etc/container-runtime-info.md so the agent can discover host/mount details.
RUNTIME_INFO="$STORAGE_DIR/runtime-info.md"
{
  echo "# Container Runtime Info"
  echo
  echo "_Generated at \`docker run\` time; regenerated on every launch._"
  echo "_Timestamp: $(date -u +"%Y-%m-%dT%H:%M:%SZ")_"
  echo
  echo "## Host"
  echo
  echo "- OS: $(uname -s) ($(uname -r))"
  echo "- Arch: $(uname -m)"
  echo "- Hostname: $(hostname)"
  echo "- User: $(whoami) (UID=$(id -u), GID=$(id -g))"
  echo
  echo "## Mounts"
  echo
  echo "| Host path | Container path | Purpose |"
  echo "|---|---|---|"
  for dir in "$@"; do
    abs=$(cd "$dir" && pwd)
    echo "| \`$abs\` | \`$abs\` | Working directory |"
  done
  echo "| \`$STORAGE_DIR/.claude\` | \`/home/agent/.claude\` | Claude Code config (persistent) |"
  echo "| \`$STORAGE_DIR/.codex\` | \`/home/agent/.codex\` | Codex config (persistent) |"
  echo "| \`$STORAGE_DIR/.config/opencode\` | \`/home/agent/.config/opencode\` | OpenCode config (persistent) |"
  echo "| \`$STORAGE_DIR/.local/share/opencode\` | \`/home/agent/.local/share/opencode\` | OpenCode auth, session, and history data (persistent) |"
  echo "| \`/var/run/docker.sock\` | \`/var/run/docker.sock\` | Host Docker daemon socket |"
  echo
  echo "## Primary Working Directory"
  echo
  echo "\`$PRIMARY_WORKDIR\`"
} > "$RUNTIME_INFO"

docker run -itd \
  --name agent-sandbox \
  --hostname sandbox \
  \
  `# Docker daemon access` \
  -v /var/run/docker.sock:/var/run/docker.sock \
  --group-add 0 \
  --group-add docker \
  \
  `# Working directories mounted at the same paths as on the host` \
  "${WORKDIR_MOUNTS[@]}" \
  -w "${PRIMARY_WORKDIR}" \
  \
  `# Persistent config for Claude Code, Codex, and OpenCode` \
  -v "$STORAGE_DIR/.claude:/home/agent/.claude" \
  -v "$STORAGE_DIR/.codex:/home/agent/.codex" \
  -v "$STORAGE_DIR/.config/opencode:/home/agent/.config/opencode" \
  -v "$STORAGE_DIR/.local/share/opencode:/home/agent/.local/share/opencode" \
  \
  `# Runtime-generated host/mount summary for the agent to read` \
  -v "$RUNTIME_INFO:/etc/container-runtime-info.md:ro" \
  \
  ghcr.io/foralan/agent-sandbox:latest
