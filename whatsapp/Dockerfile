FROM node:22-slim
RUN apt-get update && apt-get install -y git python3 build-essential curl gpg unzip procps && rm -rf /var/lib/apt/lists/*
RUN npm install -g openclaw

# gh CLI
RUN curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg -o /tmp/gh-keyring.gpg \
    && gpg --dearmor -o /usr/share/keyrings/githubcli-archive-keyring.gpg < /tmp/gh-keyring.gpg \
    && chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg \
    && echo "deb [arch=amd64 signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" > /etc/apt/sources.list.d/github-cli.list \
    && apt-get update && apt-get install -y gh && rm -rf /var/lib/apt/lists/*

# gog CLI (Google Workspace: Gmail, Calendar, Drive, Contacts)
RUN curl -sL "https://github.com/steipete/gogcli/releases/download/v0.11.0/gogcli_0.11.0_linux_amd64.tar.gz" -o /tmp/gog.tar.gz \
    && tar -xzf /tmp/gog.tar.gz -C /usr/local/bin \
    && chmod +x /usr/local/bin/gog && rm /tmp/gog.tar.gz

# himalaya CLI (IMAP/SMTP email client)
RUN curl -sL "https://github.com/pimalaya/himalaya/releases/download/v1.2.0/himalaya.x86_64-linux.tgz" -o /tmp/himalaya.tgz \
    && tar -xzf /tmp/himalaya.tgz -C /usr/local/bin \
    && chmod +x /usr/local/bin/himalaya && rm /tmp/himalaya.tgz

# OpenCode (AI coding agent)
RUN curl -fsSL https://opencode.ai/install | bash && \
    ln -s /root/.opencode/bin/opencode /usr/local/bin/opencode

# Coding agents
RUN npm install -g @anthropic-ai/claude-code @openai/codex

# Media and utility tools (yt-dlp for video, ffmpeg for media processing, jq for JSON)
RUN apt-get update && apt-get install -y ffmpeg python3-pip jq && rm -rf /var/lib/apt/lists/*
RUN pip3 install --break-system-packages yt-dlp

# Optional: custom wrapper scripts
RUN mkdir -p /opt/scripts
# COPY scripts/summarize /usr/local/bin/summarize
# RUN chmod +x /usr/local/bin/summarize

RUN mkdir -p /root/.clawdbot
WORKDIR /root

# Entrypoint: restore configs from persisted volume, then start gateway
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 19000
ENTRYPOINT ["/entrypoint.sh"]
