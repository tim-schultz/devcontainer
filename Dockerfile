FROM node:24

ARG TZ=America/Los_Angeles
ARG HOST_HOME=/home/user
ENV TZ="$TZ"

# Install basic development tools, SSH server, and networking tools
RUN apt-get update && apt-get install -y --no-install-recommends \
    less \
    git \
    procps \
    sudo \
    fzf \
    zsh \
    man-db \
    unzip \
    gnupg2 \
    gh \
    iptables \
    ipset \
    iproute2 \
    dnsutils \
    aggregate \
    jq \
    nano \
    vim \
    tmux \
    python3 \
    python3-pip \
    python3-venv \
    xclip \
    docker.io \
    docker-compose \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Install Rust build dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    pkg-config \
    libssl-dev \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Ensure default node user has access to /usr/local/share
RUN mkdir -p /usr/local/share/npm-global && \
    chown -R node:node /usr/local/share

ARG USERNAME=node

# Persist bash history
RUN SNIPPET="export PROMPT_COMMAND='history -a' && export HISTFILE=/commandhistory/.bash_history" \
    && mkdir /commandhistory \
    && touch /commandhistory/.bash_history \
    && chown -R $USERNAME /commandhistory

# Set environment variables
ENV DEVCONTAINER=true

# Create directories to match host paths exactly
# Also create .zshrc to prevent zsh-newuser-install prompt
RUN mkdir -p ${HOST_HOME}/repos ${HOST_HOME}/.claude ${HOST_HOME}/.cargo ${HOST_HOME}/go && \
    touch ${HOST_HOME}/.zshrc && \
    chown -R node:node ${HOST_HOME}

WORKDIR ${HOST_HOME}/repos

# Install git-delta for better diffs
ARG GIT_DELTA_VERSION=0.18.2
RUN ARCH=$(dpkg --print-architecture) && \
    wget "https://github.com/dandavison/delta/releases/download/${GIT_DELTA_VERSION}/git-delta_${GIT_DELTA_VERSION}_${ARCH}.deb" && \
    dpkg -i "git-delta_${GIT_DELTA_VERSION}_${ARCH}.deb" && \
    rm "git-delta_${GIT_DELTA_VERSION}_${ARCH}.deb"

# Enable passwordless sudo for node user (yolo mode)
RUN echo "node ALL=(root) NOPASSWD: ALL" > /etc/sudoers.d/node-yolo && \
    chmod 0440 /etc/sudoers.d/node-yolo

# Add node user to docker group for Docker-out-of-Docker
RUN groupadd -f docker && usermod -aG docker node

# Install git/gh safety wrappers to block remote-modifying operations (as root)
COPY git-safe.sh /usr/local/bin/git
COPY gh-safe.sh /usr/local/bin/gh
RUN chmod +x /usr/local/bin/git /usr/local/bin/gh

# Install Go (matching host version)
ARG GO_VERSION=1.18.1
RUN ARCH=$(dpkg --print-architecture) && \
    wget "https://go.dev/dl/go${GO_VERSION}.linux-${ARCH}.tar.gz" && \
    tar -C /usr/local -xzf "go${GO_VERSION}.linux-${ARCH}.tar.gz" && \
    rm "go${GO_VERSION}.linux-${ARCH}.tar.gz"

# Set up non-root user for remaining operations
USER node

# Set Rust and uv to install to HOST_HOME (matching HOME in docker-compose)
ENV CARGO_HOME=${HOST_HOME}/.cargo
ENV RUSTUP_HOME=${HOST_HOME}/.cargo

# Install Rust via rustup (as node user)
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --default-toolchain stable

# Install uv for Python project management (as node user)
# UV_INSTALL_DIR sets the directory for the binary
RUN mkdir -p ${HOST_HOME}/.local/bin && \
    curl -LsSf https://astral.sh/uv/install.sh | env UV_INSTALL_DIR=${HOST_HOME}/.local/bin sh

# Install global npm packages
ENV NPM_CONFIG_PREFIX=/usr/local/share/npm-global
ENV GOPATH=${HOST_HOME}/go
ENV PATH="${HOST_HOME}/.cargo/bin:${HOST_HOME}/.local/bin:/usr/local/share/npm-global/bin:/usr/local/go/bin:${HOST_HOME}/go/bin:$PATH"

# Set shell preferences and TERM for proper scrolling
ENV SHELL=/bin/zsh
ENV EDITOR=nano
ENV VISUAL=nano
ENV TERM=xterm-256color

# Install zsh with plugins (installs to /home/node, we'll copy to HOST_HOME)
ARG ZSH_IN_DOCKER_VERSION=1.2.0
RUN sh -c "$(wget -O- https://github.com/deluan/zsh-in-docker/releases/download/v${ZSH_IN_DOCKER_VERSION}/zsh-in-docker.sh)" -- \
    -p git \
    -p fzf \
    -a "source /usr/share/doc/fzf/examples/key-bindings.zsh 2>/dev/null || true" \
    -a "source /usr/share/doc/fzf/examples/completion.zsh 2>/dev/null || true" \
    -a "export PROMPT_COMMAND='history -a' && export HISTFILE=/commandhistory/.bash_history" \
    -a "export PATH=\$PATH:\$HOME/.local/bin:\$HOME/.cargo/bin:/usr/local/go/bin:\$HOME/go/bin" \
    -a "source \$HOME/.cargo/env 2>/dev/null || true" \
    -x && \
    cp /home/node/.zshrc ${HOST_HOME}/.zshrc

# Install common TypeScript tools
RUN npm install -g \
    typescript \
    ts-node \
    tsx

# Install Claude Code using native installer (npm method is deprecated)
# The installer puts the binary in ~/.local/bin/claude (node user's home)
# We copy to /usr/local/bin so it survives volume mounts
# Bump CLAUDE_CACHE_BUST to force re-download of latest version on rebuild
ARG CLAUDE_CACHE_BUST=2
RUN curl -fsSL https://claude.ai/install.sh | bash && \
    sudo cp /home/node/.local/bin/claude /usr/local/bin/claude

# Install OpenAI Codex CLI (sibling agent — runs alongside Claude in the same container)
# Bump CODEX_CACHE_BUST to force re-install of latest version on rebuild
ARG CODEX_CACHE_BUST=1
RUN npm install -g @openai/codex

# Install TinyClaw for multi-agent orchestration
# Installed to /opt/tinyclaw (safe from volume mount clobbering)
# Bump TINYCLAW_CACHE_BUST to force re-clone on rebuild
ARG TINYCLAW_CACHE_BUST=1
USER root
RUN git clone --depth 1 https://github.com/TinyAGI/tinyclaw.git /opt/tinyclaw && \
    chown -R node:node /opt/tinyclaw
USER node
RUN cd /opt/tinyclaw && PUPPETEER_SKIP_DOWNLOAD=true npm install && \
    mkdir -p ${HOST_HOME}/.tinyclaw

# Patch: stub missing updateAgentTeammates export (upstream bug in TinyClaw cli/team.ts)
RUN echo 'export function updateAgentTeammates(_dir: string, _id: string, _agents: Record<string, any>, _teams: Record<string, any>): void {}' \
    >> /opt/tinyclaw/packages/core/src/agent.ts

# Build TypeScript and create CLI symlink
# Skip install.sh (installs to /home/node/.local/bin which is wrong with custom HOME)
# Instead, symlink directly to /usr/local/bin so it's always on PATH
RUN cd /opt/tinyclaw && npm run build && \
    sudo ln -sf /opt/tinyclaw/bin/tinyclaw /usr/local/bin/tinyclaw

# Copy entrypoint and setup scripts
COPY --chown=node:node container-entrypoint.sh ${HOST_HOME}/container-entrypoint.sh
COPY --chown=node:node tinyclaw-setup.sh ${HOST_HOME}/tinyclaw-setup.sh
RUN chmod +x ${HOST_HOME}/container-entrypoint.sh ${HOST_HOME}/tinyclaw-setup.sh

# Copy tmux config for mouse scrolling
COPY --chown=node:node tmux.conf ${HOST_HOME}/.tmux.conf
