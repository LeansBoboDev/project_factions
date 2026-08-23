#!/usr/bin/env bash
# Recompiles the java/ class overrides in this folder against a given
# projectzomboid.jar and drops the .class files back in place, ready to
# be copied into the dedicated server.
#
# Bash equivalent of java/rebuild.ps1 (for Git Bash / WSL / Linux use).
# See README.md in this folder for when/why you need to run this.
#
# Usage:
#   ./build.sh /path/to/projectzomboid.jar

set -euo pipefail

JAR_PATH="${1:-}"
if [[ -z "$JAR_PATH" ]]; then
    echo "Usage: $0 <path to projectzomboid.jar>" >&2
    exit 1
fi
if [[ ! -f "$JAR_PATH" ]]; then
    echo "jar not found: $JAR_PATH" >&2
    exit 1
fi

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/java" && pwd)"

SRC_FILES=(
    "zombie/iso/areas/SafeHouse.java"
    "zombie/network/packets/safehouse/SafehouseClaimPacket.java"
    "zombie/network/anticheats/AntiCheatSafeHouseNotMember.java"
)

# The game's own classes (zombie.*) are compiled with a specific --release
# version (b42 uses 25); read it straight from a class already in the jar
# instead of hardcoding it, so this script keeps working across updates.
ENTRY="zombie/iso/areas/SafeHouse.class"
if ! unzip -l "$JAR_PATH" "$ENTRY" >/dev/null 2>&1; then
    echo "$ENTRY not found inside the jar - did the package layout change?" >&2
    exit 1
fi

MAJOR_HEX=$(unzip -p "$JAR_PATH" "$ENTRY" | xxd -p -s 6 -l 2 | tr -d '\n')
MAJOR_VERSION=$((16#$MAJOR_HEX))
JAVA_RELEASE=$((MAJOR_VERSION - 44))  # class file major 52 == Java 8, ... 69 == Java 25

echo "Detected class file major version $MAJOR_VERSION -> javac --release $JAVA_RELEASE"

javac --release "$JAVA_RELEASE" -encoding UTF-8 -cp "$JAR_PATH" -d "$ROOT" \
    "${SRC_FILES[@]/#/$ROOT/}"

echo "OK: recompiled into $ROOT/zombie/..."
