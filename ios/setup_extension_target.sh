#!/bin/bash
# setup_extension_target.sh
# Local helper. The CI script is the single source of truth for pbxproj
# mutations (extension target, linker flags, Runner source membership), so
# reuse it here instead of keeping a second, divergent copy.
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
exec "${SCRIPT_DIR}/setup_extension_target_ci.sh"
