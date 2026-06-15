#!/usr/bin/env sh
set -eu
cd "$(dirname "$0")"

if ! command -v node >/dev/null 2>&1; then
  echo "Node.js 20 or newer is required for the web widget." >&2
  exit 1
fi

if node -e "fetch('http://127.0.0.1:43821/api/health').then(r=>process.exit(r.ok?0:1)).catch(()=>process.exit(1))" >/dev/null 2>&1; then
  echo "Superpowers web widget is already running."
  echo "Open http://127.0.0.1:43821"
  if command -v xdg-open >/dev/null 2>&1; then
    xdg-open "http://127.0.0.1:43821" >/dev/null 2>&1 &
  elif command -v open >/dev/null 2>&1; then
    open "http://127.0.0.1:43821" >/dev/null 2>&1 &
  fi
  exit 0
fi

npm --prefix web start
