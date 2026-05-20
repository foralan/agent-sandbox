# Repository Guidelines

## Project Structure & Module Organization

- `Dockerfile` defines the Ubuntu-based image, installed CLIs, packages, aliases, and baked-in configuration.
- `build.sh` builds the local image and tags it from the latest Git tag, falling back to `dev`.
- `run.sh` starts the published image and mounts one or more host workdirs.
- `image/` contains files copied into the image: shell setup, VS Code settings/extensions, and container instructions.
- `.github/workflows/docker-build.yml` builds and pushes GHCR images on `v*` tags.
- `notes/archived/` stores historical setup notes; keep current behavior in `README.md`.
- `storage/` and `.omc/` are ignored runtime state. Do not commit credentials, generated agent config, or transient metadata.

## Build, Test, and Development Commands

- `./build.sh` builds `agent-sandbox:latest` and `agent-sandbox:<tag-or-dev>` with host UID and Docker socket GID build args.
- `./run.sh ./storage ~/projects/my-app` starts a detached `agent-sandbox` container with `/home/agent/my-app` as the working directory.
- `./run.sh ./storage ~/projects/my-app ~/projects/shared-lib` mounts multiple workdirs under `/home/agent/<basename>`; the first path becomes `-w`.
- `docker logs agent-sandbox` and `docker exec -it agent-sandbox bash` smoke test a run.

There is no automated test suite. Validate by rebuilding the image and starting a container with a disposable workdir.

## Coding Style & Naming Conventions

Shell scripts use Bash, two-space indentation in continued Docker commands, quoted variables, and uppercase derived paths such as `STORAGE_DIR`. Keep scripts executable.

Use lowercase, hyphenated names for documentation and setup notes. Prefer concise Markdown with command examples in fenced `bash` blocks. Keep Dockerfile changes grouped by tool category and update `README.md` when installed tools or mounts change.

## Testing Guidelines

For Dockerfile or script changes, run:

```bash
mkdir -p /tmp/agent-sandbox-smoke
./build.sh
./run.sh ./storage /tmp/agent-sandbox-smoke
docker exec -it agent-sandbox bash
```

Inside the container, verify affected tools directly: `codex --version`, `claude --version`, `gh --version`, `docker ps`, or `rg --version`.

## Commit & Pull Request Guidelines

Git history uses short imperative subjects, for example `Add SSH/tmux support, crawl4ai, and organize setup notes`. Keep commits focused on one behavior or documentation update.

Pull requests should describe the image/runtime change, list manual verification commands, mention new host requirements, and link related issues. Include screenshots only for changes affecting VS Code, browser tooling, or visual assets.

## Security & Configuration Tips

Never commit files from ignored runtime storage. Treat `storage/.claude`, `storage/.codex`, GitHub auth, and API keys as local secrets. When adding new mounts or credentials, document persistence and host access implications in `README.md`.
