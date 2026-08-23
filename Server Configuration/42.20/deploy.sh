#!/usr/bin/env bash
# Recompiles the java/ class overrides and deploys them to the dedicated server.
#
# Usage:
#   ./deploy.sh /path/to/dedicated-server
#
# Example:
#   ./deploy.sh "$HOME/.local/share/Steam/steamapps/common/Project Zomboid Dedicated Server"

set -euo pipefail

SERVER_DIR="${1:-}"
if [[ -z "$SERVER_DIR" ]]; then
    echo "Usage: $0 <path to dedicated server directory>" >&2
    exit 1
fi
if [[ ! -d "$SERVER_DIR" ]]; then
    echo "Server directory not found: $SERVER_DIR" >&2
    exit 1
fi

JAR_PATH="$SERVER_DIR/java/projectzomboid.jar"
if [[ ! -f "$JAR_PATH" ]]; then
    echo "projectzomboid.jar not found at: $JAR_PATH" >&2
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "==> Building class overrides against $JAR_PATH ..."
bash "$SCRIPT_DIR/build.sh" "$JAR_PATH"

echo "==> Deploying java/ to $SERVER_DIR ..."
cp -r "$SCRIPT_DIR/java" "$SERVER_DIR/"

echo "OK: deployed to $SERVER_DIR/java/zombie/..."
