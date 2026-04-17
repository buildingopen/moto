# shellcheck shell=bash
# (sourced from ~/.zshrc.d/; zsh-compatible syntax)
# moto — SSH helpers
# Sourced from ~/.zshrc.d/ by the loader stanza.

# Ensure the socket dir for ControlMaster exists.
[[ -d "$HOME/.ssh/sockets" ]] || mkdir -p "$HOME/.ssh/sockets"
