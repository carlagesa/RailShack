#!/usr/bin/env bash
# RailShack · 50 Microservices Project by DevOps Shack
# Copyright (c) 2026 DevOps Shack (Aditya Jaiswal) · https://devopsshack.com · https://www.youtube.com/@devopsshack
# SPDX-License-Identifier: Apache-2.0
# Runs all 50 RailShack microservices directly on your machine (no Docker needed).
# Needs: Go 1.24+, Node.js 22+, Python 3.13+, JDK 21, and curl.
# Starts all 50 services directly from source for local development and CI.
# Each service gets its own port from services.json (9001-9050); the smoke test talks to the frontend on 9050.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
RUN="$ROOT/.run"
mkdir -p "$RUN/bin" "$RUN/java" "$RUN/logs" "$RUN/pids"
export PORTS_FILE="$ROOT/services.json"
export NODE_PATH="$ROOT/libs/nodekit"
export PYTHONPATH="$ROOT/libs/pykit"
export APP_ENV="${APP_ENV:-local}" CLUSTER_NAME="${CLUSTER_NAME:-local}"

PYTHON_BIN="${PYTHON:-python3}"
if ! command -v "$PYTHON_BIN" >/dev/null 2>&1; then
  PYTHON_BIN=python
fi
if ! command -v "$PYTHON_BIN" >/dev/null 2>&1; then
  echo "Python 3 is required to read services.json" >&2
  exit 1
fi

jq_lines() { "$PYTHON_BIN" -c "import json,sys;[print(s['name'],s['lang'],s['port']) for s in json.load(open('$PORTS_FILE'))]"; }

echo "▶ building Go and Java services..."
while read -r name lang port; do
  case "$lang" in
    go)   (cd "$ROOT/services/$name" && CGO_ENABLED=0 go build -o "$RUN/bin/$name" .) ;;
    java) javac -d "$RUN/java/$name" "$ROOT/libs/javakit/Kit.java" "$ROOT/services/$name/Main.java" ;;
  esac
done < <(jq_lines)

echo "▶ starting 50 services..."
while read -r name lang port; do
  log="$RUN/logs/$name.log"
  export POD_NAME="${name}-local"
  case "$lang" in
    go)     PORT=$port "$RUN/bin/$name" >"$log" 2>&1 & ;;
    node)   PORT=$port node "$ROOT/services/$name/index.js" >"$log" 2>&1 & ;;
    python) PORT=$port "$PYTHON_BIN" "$ROOT/services/$name/app.py" >"$log" 2>&1 & ;;
    java)   PORT=$port java -Xmx96m -cp "$RUN/java/$name" Main >"$log" 2>&1 & ;;
  esac
  echo $! > "$RUN/pids/$name.pid"
done < <(jq_lines)

echo "▶ waiting for health checks..."
for i in $(seq 1 60); do
  up=0
  while read -r name lang port; do curl -sf "http://127.0.0.1:$port/healthz" >/dev/null && up=$((up+1)); done < <(jq_lines)
  [ "$up" -eq 50 ] && break
  sleep 1
done
if [ "$up" -ne 50 ]; then
  echo "❌ Only $up/50 services became healthy; inspect .run/logs" >&2
  exit 1
fi
echo "✅ $up/50 services healthy (logs in .run/logs)"
