#!/bin/bash
set -e

ROLE="$1"
DOMAIN_OR_IP="$2"
CONFIG_DIR="$HOME/.${ROLE}"
BIN_DIR="/usr/local/bin"
SERVICE_FILE="/etc/systemd/system/${ROLE}.service"

if [[ "$ROLE" != "server" && "$ROLE" != "client" ]]; then
  echo "Usage: $0 [server|client] <server-ip-or-domain>"
  exit 1
fi

echo "🚀 حالت: $ROLE، آدرس: $DOMAIN_OR_IP"

# نصب Go (اگر نیاز باشه):
if ! command -v go &>/dev/null; then
  apt update && apt install -y golang git
fi

# ساخت باینری
if ! command -v tunneld &>/dev/null && [ "$ROLE" = "server" ]; then
  go install github.com/mmatczuk/go-http-tunnel/cmd/tunneld@latest
fi
if ! command -v tunnel &>/dev/null && [ "$ROLE" = "client" ]; then
  go install github.com/mmatczuk/go-http-tunnel/cmd/tunnel@latest
fi

mkdir -p "$CONFIG_DIR"
cd "$CONFIG_DIR"

# ساخت TLS و کانفیگ
if [[ "$ROLE" == "server" ]]; then
  openssl req -x509 -nodes -newkey rsa:2048 -sha256 \
    -keyout server.key -out server.crt -subj "/CN=$DOMAIN_OR_IP"
  mv "$(go env GOPATH)/bin/tunneld" "$BIN_DIR/"

  cat > "$SERVICE_FILE" <<EOF
[Unit]
Description=Go HTTP Tunnel Server
After=network.target

[Service]
ExecStart=$BIN_DIR/tunneld -tlsCrt $CONFIG_DIR/server.crt -tlsKey $CONFIG_DIR/server.key
Restart=on-failure
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

elif [[ "$ROLE" == "client" ]]; then
  openssl req -x509 -nodes -newkey rsa:2048 -sha256 \
    -keyout client.key -out client.crt -subj "/CN=$DOMAIN_OR_IP"
  mv "$(go env GOPATH)/bin/tunnel" "$BIN_DIR/"

  cat > tunnel.yml <<EOF
server_addr: $DOMAIN_OR_IP:5223
tunnels:
  http:
    proto: http
    addr: localhost:80
    auth: user:pass
    host: $DOMAIN_OR_IP
EOF

  cat > "$SERVICE_FILE" <<EOF
[Unit]
Description=Go HTTP Tunnel Client
After=network.target

[Service]
ExecStart=$BIN_DIR/tunnel -config $CONFIG_DIR/tunnel.yml start-all
Restart=on-failure
RestartSec=10
WorkingDirectory=$CONFIG_DIR

[Install]
WantedBy=multi-user.target
EOF
fi

echo "فعال‌سازی سرویس و اجرای اولیه..."
chmod +x "$SERVICE_FILE"
systemctl daemon-reload
systemctl enable --now "${ROLE}.service"

echo "✅ سرور $ROLE آماده است و سرویس با systemd فعال شد."
