#!/usr/bin/env bash
set -euo pipefail

frontend_port="${GREENMART_WEB_PORT:-8081}"
backend_port="${EAZYERP_BACKEND_PORT:-8080}"

flutter build web --dart-define="EAZYERP_BASE_URL="
python3 tool/local_same_origin_proxy.py \
  --port "$frontend_port" \
  --backend-port "$backend_port"
