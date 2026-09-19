#!/bin/bash
set -euo pipefail

tests_root="$(cd "$(dirname "$0")" && pwd)"
source_root="$(cd "$tests_root/.." && pwd)"
if [[ ! -d "$source_root/CueTap.xcodeproj" ]]; then
    printf 'Source project not found: %s/CueTap.xcodeproj\n' "$source_root" >&2
    exit 2
fi
mode="${1:-all}"
if [[ "$mode" != all && "$mode" != --unit ]]; then
    printf 'Usage: %s [--unit]\nRuns all tests by default; --unit runs tests that do not require system permissions.\n' "$0" >&2
    exit 2
fi
if [[ "$mode" == all ]] && pgrep -x cuetap >/dev/null; then
    printf 'Quit all running cuetap processes before native integration tests.\n' >&2
    exit 3
fi
cd "$source_root"
xcodebuild -project CueTap.xcodeproj -scheme CueTap -configuration Debug \
    -destination 'platform=macOS,arch=arm64' -derivedDataPath build/DerivedData \
    -quiet build-for-testing

if [[ "$mode" == --unit ]]; then
    xcrun xctest -XCTest DemoControllerTests,DemoScriptTests,CommandOptionsTests,ConfigurationCLITests,DemoInputSourceTests,DemoHotkeyTests,RuntimeSettingsTests,MultiSegmentTests,ConfigurationStoreTests,ConfigurationCommandsTests,DoctorTests,CompletionLockTests build/products/Debug/CueTapTests.xctest \
        2>&1 | tee build/unit-test-output.log
else
    if pgrep -x cuetap >/dev/null; then
        printf 'Quit all running cuetap processes before native integration tests to avoid conflicting interceptors.\n' >&2
        exit 3
    fi
    build/products/Debug/cuetap --check
    xcrun xctest build/products/Debug/CueTapTests.xctest 2>&1 | tee build/test-output.log
    if /usr/bin/grep -Eq 'Test Case .* skipped' build/test-output.log; then
        printf 'Native tests were skipped due to permissions or the graphical session. Acceptance is incomplete.\n' >&2
        exit 3
    fi
fi

xcodebuild -project CueTap.xcodeproj -scheme CueTap -configuration Release \
    -destination 'platform=macOS,arch=arm64' -derivedDataPath build/DerivedData -quiet build
# Same re-signing as the build script: the entitlement Xcode injects costs the menu bar icon.
codesign --remove-signature "$source_root/build/products/Release/cuetap"
codesign --force --sign - "$source_root/build/products/Release/cuetap"
printf '\nTests and Release build passed. Executable: %s/build/products/Release/cuetap\n' "$source_root"
