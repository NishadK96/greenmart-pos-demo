#!/usr/bin/env bash
set -euo pipefail

backend_url="${EAZYERP_LOCAL_URL:-http://localhost:8080}"
frontend_port="${GREENMART_WEB_PORT:-5050}"

client_secret="$(docker exec eazyerp-db-1 mysql -N -s -uroot -proot pos \
  -e 'SELECT secret FROM oauth_clients WHERE password_client=1 AND revoked=0 ORDER BY id DESC LIMIT 1;' \
  2>/dev/null)"

if [[ -z "$client_secret" ]]; then
  echo "No active local Passport password client was found." >&2
  exit 1
fi

flutter run -d web-server \
  --web-hostname 127.0.0.1 \
  --web-port "$frontend_port" \
  --dart-define="EAZYERP_BASE_URL=$backend_url" \
  --dart-define=EAZYERP_CLIENT_ID=2 \
  --dart-define="EAZYERP_CLIENT_SECRET=$client_secret"
