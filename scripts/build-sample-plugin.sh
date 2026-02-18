#!/usr/bin/env bash

set -euo pipefail

# Default values
TAG=""
NAME=""
OUTPUT_DIR=""
BUILD_DIR=""
WITH_AVSC=false
CLEANUP_BUILD_DIR=true

# Parse command line arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --tag)
      TAG="$2"
      shift 2
      ;;
    --name)
      NAME="$2"
      shift 2
      ;;
    --output-dir)
      OUTPUT_DIR="$2"
      shift 2
      ;;
    --build-dir)
      BUILD_DIR="$2"
      shift 2
      ;;
    --with-avsc)
      WITH_AVSC=true
      shift
      ;;
    --no-cleanup-build-dir)
      CLEANUP_BUILD_DIR=false
      shift
      ;;
    *)
      echo "Unknown argument: $1"
      exit 1
      ;;
  esac
done

if [ -z "$TAG" ]; then
  echo "Error: --tag argument is required"
  exit 1
fi

if [ -z "$NAME" ]; then
  echo "Error: --name argument is required"
  exit 1
fi

cd -P -- "$(dirname -- "${BASH_SOURCE[0]}")/.."
ROOT_DIR="$(pwd)"

echo "Installing rebar template"

./scripts/install-rebar-template.sh

echo "Creating plugin"

rm -rf "$NAME"
"$ROOT_DIR/rebar3" new emqx-plugin "$NAME" version="$TAG"

PLUGIN_DIR="$ROOT_DIR/$NAME"
if [ -n "$BUILD_DIR" ]; then
  mkdir -p "$BUILD_DIR"
  rm -rf "$BUILD_DIR/$NAME"
  mv "$NAME" "$BUILD_DIR/"
  PLUGIN_DIR="$BUILD_DIR/$NAME"
fi

mv "$PLUGIN_DIR/priv/config.hocon.example" "$PLUGIN_DIR/priv/config.hocon"

if [ "$WITH_AVSC" = true ]; then
  mv "$PLUGIN_DIR/priv/config_schema.avsc.enterprise.example" "$PLUGIN_DIR/priv/config_schema.avsc"
  mv "$PLUGIN_DIR/priv/config_i18n.json.example" "$PLUGIN_DIR/priv/config_i18n.json"
fi

echo "Building plugin"
export BUILD_WITHOUT_QUIC=1
make -C "$PLUGIN_DIR" rel

echo "Copying plugin to $OUTPUT_DIR"
if [ -n "$OUTPUT_DIR" ]; then
  mkdir -p "$OUTPUT_DIR"
  cp "$PLUGIN_DIR"/_build/default/emqx_plugrel/*.tar.gz "$OUTPUT_DIR"
fi


if [ "$CLEANUP_BUILD_DIR" = true ]; then
  echo "Cleaning up"
  rm -rf "$PLUGIN_DIR"
else
  echo "Skipping cleanup"
fi
