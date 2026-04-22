# moto — dev-sandbox
# sshd + node + python + git. SSH in from your Mac:
#   ssh -p 2223 root@<AX41_HOST>
# Intended as an isolated playground for experiments that might trash the host.

FROM debian:bookworm-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
      openssh-server sudo curl wget git ca-certificates \
      build-essential python3 python3-pip python3-venv \
      tmux vim less \
      fonts-liberation \
    && rm -rf /var/lib/apt/lists/*

# Node 22 via NodeSource.
RUN curl -fsSL https://deb.nodesource.com/setup_22.x | bash - \
    && apt-get install -y nodejs \
    && rm -rf /var/lib/apt/lists/*

# Basic sshd config.
RUN mkdir -p /run/sshd \
    && sed -i 's/#PermitRootLogin.*/PermitRootLogin prohibit-password/' /etc/ssh/sshd_config \
    && sed -i 's/#PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config

# Copy the host's id_ed25519.pub into authorized_keys at first boot.
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

EXPOSE 22
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["/usr/sbin/sshd", "-D", "-e"]
