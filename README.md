# agent-sandbox

A Docker image running [Claude Code](https://claude.ai/code), [Codex](https://github.com/openai/codex), and [OpenCode](https://opencode.ai/) on an unminimized Ubuntu 24.04 LTS base, with Docker CLI and GitHub CLI included.

## Build

```bash
./build.sh
```

This passes two build args:
- `USER_UID` — your host UID, so `agent` can read/write mounted files without `sudo`
- `DOCKER_GID` — the host's Docker socket GID (auto-detected on macOS/Linux), so `agent` can talk to the host Docker daemon without `sudo`

## Run

Use the provided script:

```bash
# Mount a single directory
./run.sh ./storage ~/projects/my-app

# Mount multiple directories
./run.sh ./storage ~/projects/my-app ~/projects/shared-lib

# Use shared persistent storage on this host
./run.sh /Users/yangyixuan/docker-shared/agent-sandbox ~/projects/my-app
```

Each workdir is mounted under `/home/agent/<basename>`. For example, `/Users/yangyixuan/development` is mounted at `/home/agent/development`. The container starts in the image's default working directory, `/home/agent`.

The script mounts:

| Mount | Host path | Container path | Notes |
|---|---|---|---|
| Working directories | each workdir arg | `/home/agent/<basename>` | read/write |
| Claude Code config | `<storage-dir>/.claude` | `/home/agent/.claude` | persistent |
| Codex config | `<storage-dir>/.codex` | `/home/agent/.codex` | persistent |
| OpenCode config | `<storage-dir>/.config/opencode` | `/home/agent/.config/opencode` | persistent |
| OpenCode auth/session/history | `<storage-dir>/.local/share/opencode` | `/home/agent/.local/share/opencode` | persistent |
| OpenCode state | `<storage-dir>/.local/state/opencode` | `/home/agent/.local/state/opencode` | persistent |
| Docker socket | `/var/run/docker.sock` | `/var/run/docker.sock` | host Docker daemon |

## Authentication

On first run, log in to each tool as needed — credentials are persisted via the mounts above so you only need to do this once:

- **Claude Code**: run `claude` and follow the browser prompts, or set `ANTHROPIC_API_KEY`
- **Codex**: set `OPENAI_API_KEY`
- **OpenCode**: run `opencode auth login` or start `opencode` and use `/connect`
- **GitHub CLI**: run `gh auth login`

## Aliases

The image ships a few convenience aliases:

```bash
oc            # opencode
ccy           # claude --dangerously-skip-permissions
cxy           # codex --dangerously-bypass-approvals-and-sandbox
```

OpenCode keeps its config under `/home/agent/.config/opencode`, auth/session/history data under `/home/agent/.local/share/opencode`, and state under `/home/agent/.local/state/opencode`. These default paths are mounted into `<storage-dir>` so records survive container restarts without setting `XDG_*` environment variables.

Container instructions are baked into `/etc/claude-code/CLAUDE.md` (Linux managed policy path), which Claude Code auto-loads at conversation start.

## Git identity

`~/.gitconfig` is **not** mounted from the host. Set your identity once inside the container (it persists via `~/.claude` / `~/.codex` if your tooling stores it there) or export it via env vars:

```bash
git config --global user.name "Your Name"
git config --global user.email "you@example.com"
```

## What's installed

| Category | Tool | Install method |
|---|---|---|
| Base OS | Ubuntu 24.04 LTS with restored man pages, docs, and locales | `unminimize` |
| AI CLIs | Claude Code | Official shell script (auto-updates) |
| AI CLIs | Codex CLI, OpenCode, `@larksuite/cli`, Bitwarden CLI (`bw`) | npm (installed as `agent`) |
| Runtime | Node.js 22 LTS, Bun | NodeSource + official installer |
| Runtime | Python 3 + `pipx`, `uv` | apt + official installer |
| Container | Docker CLI | Docker apt repo (socket mounted from host) |
| VCS | GitHub CLI (`gh`), `git` | GitHub apt repo / apt |
| Search / JSON | `ripgrep`, `jq` | apt |
| Office / PDF | LibreOffice Impress, Poppler, `markitdown[pptx]` | apt / pipx |
| Diagrams | draw.io Desktop + `xvfb` | GitHub release / apt |
| Web scraping | `crawl4ai` (Playwright Chromium) | pipx |
| Dev tools | `build-essential`, `jq`, `vim`, `nano`, `make`, `wget`, `zip/unzip`, `tmux`, `openssh-client` | apt |

## Accessing host services from the container

`--network=host` does not work on Docker Desktop for Mac. Use `host.docker.internal` instead — Docker Desktop automatically resolves this to the Mac host's IP from inside any container:

```bash
# e.g. a Postgres running on the Mac host
psql -h host.docker.internal -p 5432

# e.g. a local web server
curl http://host.docker.internal:8080
```

This works for any service running on the host without any extra flags in `run.sh`.

## Docker CLI access

Docker CLI is included in the image and the host's `/var/run/docker.sock` is mounted into the container, so `agent` can run `docker` commands against the host Docker daemon:

```bash
docker ps          # lists host containers
docker build ...   # uses host's daemon; images land on the host
```

`build.sh` auto-detects the host socket's GID (macOS uses `stat -f`, Linux uses `stat -c`) and bakes it into the image's `docker` group. `run.sh` also passes `--group-add 0` because on Docker Desktop for Mac the socket always appears as GID 0 inside the container regardless of the baked-in `DOCKER_GID`.

## Notes

- The container runs as a non-root user (`agent`) with passwordless `sudo`.
- npm global packages are installed into `/home/agent/.local`, not under `root`.
