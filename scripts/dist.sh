#!/bin/bash -e

# =======================================================================================
#
# Build PostgreSQL.prefPane for release, then package it in a codesigned & notarized .dmg
#
# =======================================================================================

SCRIPT_DIR=$(cd "$(dirname "$BASH_SOURCE")"; cd -P "$(dirname "$(readlink "$BASH_SOURCE" || echo .)")"; pwd)
ROOT_DIR=$(dirname "$SCRIPT_DIR")

cd "$ROOT_DIR"

# Build
xcodebuild -project PostgreSQL.xcodeproj -scheme PostgreSQL -configuration Release -derivedDataPath build

# Notarize
"$SCRIPT_DIR"/notarize.sh
