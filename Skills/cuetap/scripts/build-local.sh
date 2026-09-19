#!/bin/bash
set -euo pipefail
# Development fallback until the public Homebrew release is available.
if [[ $# -gt 1 ]]; then
    printf 'Usage: %s [CueTap project root]\n' "$0" >&2
    exit 2
fi
script_dir="$(cd "$(dirname "$0")" && pwd)"
project_dir="${1:-$script_dir/../../..}"
if [[ ! -d "$project_dir/CueTap.xcodeproj" ]]; then
    printf 'CueTap.xcodeproj not found. Supply the source project root. No Homebrew formula has been published yet.\n' >&2
    exit 2
fi
project_dir="$(cd "$project_dir" && pwd)"
if pgrep -x cuetap >/dev/null; then
    printf 'Run cuetap quit before rebuilding.\n' >&2
    exit 3
fi
xcodebuild -project "$project_dir/CueTap.xcodeproj" -scheme CueTap -configuration Release \
    -destination 'platform=macOS,arch=arm64' -derivedDataPath "$project_dir/build/DerivedData" -quiet build
# Xcode signs the tool with an empty com.apple.application-identifier entitlement, and a process
# carrying it is never given a menu bar slot: the status item stays invisible while isVisible
# still reports true. Re-sign ad hoc with no entitlements at all.
binary="$project_dir/build/products/Release/cuetap"
codesign --remove-signature "$binary"
codesign --force --sign - "$binary"
"$binary" version --json
printf 'Local executable: %s/build/products/Release/cuetap\n' "$project_dir"
printf 'Keep html-demo.json beside the executable for first startup. Menu icons use SF Symbols. Not installed to PATH.\n'
