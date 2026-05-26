FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive
ENV LANG=en_US.UTF-8
ENV LC_ALL=en_US.UTF-8
ENV UV_PROJECT_ENVIRONMENT=.linux_venv

# Restore man pages, documentation, and locales for an interactive dev image.
RUN yes | unminimize \
    && rm -rf /var/lib/apt/lists/*

# Install base dependencies and common dev tools
RUN apt-get update && apt-get install -y \
    build-essential \
    ca-certificates \
    curl \
    git \
    gnupg \
    jq \
    lsb-release \
    make \
    nano \
    openssh-client \
    ripgrep \
    sudo \
    tmux \
    unzip \
    vim \
    wget \
    zip \
    locales \
    pipx \
    python3-pip \
    python3-venv \
    && locale-gen en_US.UTF-8 \
    && rm -rf /var/lib/apt/lists/*

# Install Node.js 22 LTS via NodeSource (current official method)
RUN mkdir -p /etc/apt/keyrings \
    && curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key \
       | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg \
    && echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_22.x nodistro main" \
       > /etc/apt/sources.list.d/nodesource.list \
    && apt-get update && apt-get install -y nodejs \
    && rm -rf /var/lib/apt/lists/*

# Install GitHub CLI
RUN curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
    | dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg \
    && chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] \
       https://cli.github.com/packages stable main" \
       > /etc/apt/sources.list.d/github-cli.list \
    && apt-get update && apt-get install -y gh \
    && rm -rf /var/lib/apt/lists/*

# Install Docker CLI
RUN curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] \
       https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" \
       > /etc/apt/sources.list.d/docker.list \
    && apt-get update && apt-get install -y docker-ce-cli \
    && rm -rf /var/lib/apt/lists/*

# Install draw.io desktop (arch-aware: amd64 or arm64)
RUN ARCH=$(dpkg --print-architecture) \
    && curl -fsSL "https://github.com/jgraph/drawio-desktop/releases/download/v29.6.6/drawio-${ARCH}-29.6.6.deb" \
       -o /tmp/drawio.deb \
    && apt-get update \
    && apt-get install -y /tmp/drawio.deb xvfb \
    && rm /tmp/drawio.deb \
    && rm -rf /var/lib/apt/lists/*

# LibreOffice + Poppler for PPTX/PDF workflows
RUN apt-get update && apt-get install -y --no-install-recommends \
    libreoffice-impress libreoffice-common poppler-utils \
    && rm -rf /var/lib/apt/lists/*

# Create a non-root user with sudo and Docker socket access
# DOCKER_GID must match the host's docker socket GID for passwordless docker access
ARG USER_UID=1000
ARG DOCKER_GID=999
RUN groupadd -f -g ${DOCKER_GID} docker \
    && userdel -r ubuntu 2>/dev/null || true \
    && useradd -m -s /bin/bash -u ${USER_UID} agent \
    && usermod -aG docker,sudo agent \
    && echo "agent ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/agent

# Bake managed policy (auto-loaded by Claude Code on Linux)
COPY image/container-instructions.md /etc/claude-code/CLAUDE.md

# VS Code extensions list
COPY --chown=agent:agent image/vscode-extensions.txt /home/agent/.vscode-extensions.txt

USER agent
WORKDIR /home/agent

# Suppress Ubuntu's "sudo hint" message on shell start
RUN touch /home/agent/.sudo_as_admin_successful

# Install user-scoped Node.js tools and runtimes
ENV BUN_INSTALL="/home/agent/.bun"
ENV NPM_CONFIG_PREFIX="/home/agent/.local"
ENV PATH="/home/agent/.bun/bin:/home/agent/.local/bin:$PATH"
RUN curl -fsSL https://bun.sh/install | bash
RUN npm install -g @openai/codex @larksuite/cli opencode-ai @bitwarden/cli @playwright/cli@latest

# Install Claude Code via official shell script
RUN curl -fsSL https://claude.ai/install.sh | bash

# Install uv (Python package manager)
RUN curl -LsSf https://astral.sh/uv/install.sh | sh

# Install crawl4ai and Playwright Chromium browser
RUN pipx install crawl4ai && crawl4ai-setup

# Install markitdown for PPTX text extraction
RUN pipx install "markitdown[pptx]"

# Bake VS Code user settings (enables Claude Code auto-approve inside container)
RUN mkdir -p /home/agent/.config/Code/User
COPY --chown=agent:agent image/vscode-settings.json /home/agent/.config/Code/User/settings.json

# Symlink AGENTS.md -> CLAUDE.md so Codex reads the same instructions (CODEX_HOME defaults to ~)
RUN ln -s /etc/claude-code/CLAUDE.md /home/agent/AGENTS.md

# Convenience aliases and venv reminders
COPY --chown=agent:agent image/bashrc /home/agent/.bashrc

CMD ["bash"]
