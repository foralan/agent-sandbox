# Agent Container Instructions

## Environment

You are running inside a **Docker container (Ubuntu 24.04 LTS)**. You are the non-root user `agent` with passwordless `sudo`. The shell is `bash`. Do **not** assume anything about the host operating system.

## Preinstalled Tools

This image ships with the following so you do not need to install them yourself:

| Category | Tools |
|---|---|
| AI CLIs | `claude` (Claude Code), `codex` (OpenAI Codex), `opencode`, `@larksuite/cli` |
| VCS | `git`, `gh` (GitHub CLI) |
| Container | `docker` CLI (talks to the host Docker daemon via mounted socket) |
| Node.js | Node 22 LTS + `npm`, `npx`, `bun` |
| Python | `python3`, `pip`, `pipx`, `uv` |
| Python apps | `crawl4ai` (with Playwright Chromium), `markitdown[pptx]` |
| Office/PDF | `libreoffice-impress`, `poppler-utils` (pdftoppm, pdftotext, …) |
| Diagrams | `drawio` Desktop + `xvfb`/`xvfb-run` for headless export |
| Shell / editors | `bash`, `tmux`, `vim`, `nano` |
| Search / JSON | `ripgrep` (`rg`), `jq` |
| Net / archive | `curl`, `wget`, `zip`, `unzip`, `openssh-client` |
| Build | `build-essential`, `make` |

## Network

The container uses **bridge mode** networking. Do not use `localhost` to reach services on the host machine — it will only resolve to the container itself.

To reach a service running on the host, use:
```
host.docker.internal:<port>
```

Examples:
- PostgreSQL on the host: `host.docker.internal:5432`
- A local web server: `host.docker.internal:8080`

This works on Docker Desktop (macOS/Windows) out of the box. On native Linux Docker it only resolves if the container was started with `--add-host=host.docker.internal:host-gateway`; fall back to the host's actual IP if needed.

## draw.io Export

draw.io Desktop is installed and can export `.drawio` files from the terminal. It requires a virtual X display — `--headless` alone is not sufficient in this container.

**Always use `xvfb-run`:**

```bash
# Export to PNG
xvfb-run -a drawio --no-sandbox -x -f png your-file.drawio

# Export to PNG and embed the original diagram XML
xvfb-run -a drawio --no-sandbox -x -f png -e your-file.drawio
```

Key rules:
- Do **not** pass extra Chromium flags (e.g. `--disable-gpu`) — the CLI parser may treat them as the input path and fail with `Error: input file/directory not found`.
- `xvfb-run` and `Xvfb` are already installed at `/usr/bin/`.
