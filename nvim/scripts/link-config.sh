#!/usr/bin/env bash

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SOURCE_DIR="$REPO_DIR"
TARGET_DIR="${HOME}/.config/nvim"
CONFIG_DIR="$(dirname "$TARGET_DIR")"

mkdir -p "$CONFIG_DIR"

if [ -L "$TARGET_DIR" ]; then
  CURRENT_TARGET="$(readlink "$TARGET_DIR")"
  if [ "$CURRENT_TARGET" = "$SOURCE_DIR" ]; then
    echo "Symlink already configured: $TARGET_DIR -> $SOURCE_DIR"
    exit 0
  fi

  rm "$TARGET_DIR"
fi

if [ -e "$TARGET_DIR" ]; then
  echo "Refusing to overwrite existing path: $TARGET_DIR" >&2
  echo "Move or remove it yourself, then rerun this script." >&2
  exit 1
fi

ln -s "$SOURCE_DIR" "$TARGET_DIR"
echo "Linked $TARGET_DIR -> $SOURCE_DIR"
