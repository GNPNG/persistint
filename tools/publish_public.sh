#!/usr/bin/env bash
# SOP-14 publication, kept as the historical entry point: runs the targets in .config/publish.toml.
#   tools/publish_public.sh [--dry-run] [--only NAME]
exec python3 -I "$(dirname "$0")/publish.py" --repo "$(cd "$(dirname "$0")/.." && pwd)" "$@"
