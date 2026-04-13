#!/usr/bin/env bash
# SessionStart hook: installs Tailscale in the sandbox, joins the tailnet,
# and drops the SSH key/config needed to reach alex-pi5.
#
# Required environment variables (configure these as secrets in the Claude
# Code on the web workspace — do NOT commit them):
#   TS_AUTHKEY   — Tailscale reusable/ephemeral auth key (tskey-auth-...)
#   PI_SSH_KEY   — private key (contents) authorized on alex-pi5
#
# Idempotent: safe to run on every session start.

set -euo pipefail

log() { echo "[setup-tailscale] $*" >&2; }

if [[ -z "${TS_AUTHKEY:-}" ]]; then
  log "TS_AUTHKEY not set — skipping Tailscale setup."
  exit 0
fi

# 1. Install Tailscale if missing
if ! command -v tailscale >/dev/null 2>&1; then
  log "Installing Tailscale..."
  curl -fsSL https://tailscale.com/install.sh | sh
fi

# 2. Start tailscaled in userspace-networking mode (no TUN device needed)
if ! pgrep -x tailscaled >/dev/null 2>&1; then
  log "Starting tailscaled (userspace networking)..."
  sudo tailscaled \
    --tun=userspace-networking \
    --socks5-server=localhost:1055 \
    --state=/var/lib/tailscale/tailscaled.state \
    >/tmp/tailscaled.log 2>&1 &
  # Give the daemon a moment to open its socket
  for _ in 1 2 3 4 5; do
    [[ -S /var/run/tailscale/tailscaled.sock ]] && break
    sleep 1
  done
fi

# 3. Bring the node up on the tailnet
if ! sudo tailscale status >/dev/null 2>&1; then
  log "Authenticating to tailnet..."
  sudo tailscale up \
    --authkey="$TS_AUTHKEY" \
    --hostname=claude-sandbox \
    --ssh \
    --accept-dns=true
fi

# 4. Drop the SSH key and config for alex-pi5
if [[ -n "${PI_SSH_KEY:-}" ]]; then
  mkdir -p "$HOME/.ssh"
  chmod 700 "$HOME/.ssh"
  printf '%s\n' "$PI_SSH_KEY" > "$HOME/.ssh/id_ed25519_pi"
  chmod 600 "$HOME/.ssh/id_ed25519_pi"

  # Write ~/.ssh/config entry idempotently
  if ! grep -q '^Host alex-pi5$' "$HOME/.ssh/config" 2>/dev/null; then
    cat >> "$HOME/.ssh/config" <<'EOF'

Host alex-pi5
  HostName alex-pi5
  User alex
  IdentityFile ~/.ssh/id_ed25519_pi
  StrictHostKeyChecking accept-new
EOF
    chmod 600 "$HOME/.ssh/config"
  fi
fi

log "Tailscale ready. Try: ssh alex-pi5"
