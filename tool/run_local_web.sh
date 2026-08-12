#!/usr/bin/env bash
set -euo pipefail

backend_url="${EAZYERP_LOCAL_URL:-http://localhost:8080}"
frontend_port="${GREENMART_WEB_PORT:-5050}"

flutter run -d web-server \
  --web-hostname 127.0.0.1 \
  --web-port "$frontend_port" \
  --dart-define="EAZYERP_BASE_URL=$backend_url"
