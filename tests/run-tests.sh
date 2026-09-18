#!/bin/bash
set -euo pipefail

tests_root="$(cd "$(dirname "$0")" && pwd)"
source_root="$(cd "$tests_root/.." && pwd)"
if [[ ! -d "$source_root/CueTap.xcodeproj" ]]; then
    printf '未找到源码工程：%s/CueTap.xcodeproj\n' "$source_root" >&2
    exit 2
fi
mode="${1:-all}"
if [[ "$mode" != all && "$mode" != --unit ]]; then
    printf '用法：%s [--unit]\n默认执行全部测试；--unit 只运行不需要系统权限的进度、配置、命令行和输入源控制测试。\n' "$0" >&2
    exit 2
fi
if [[ "$mode" == all ]] && pgrep -x cuetap >/dev/null; then
    printf '请先结束正在运行的 cuetap 进程，再执行原生集成测试。\n' >&2
    exit 3
fi
cd "$source_root"
xcodebuild -project CueTap.xcodeproj -scheme CueTap -configuration Debug \
    -destination 'platform=macOS,arch=arm64' -derivedDataPath build/DerivedData \
    -quiet build-for-testing

if [[ "$mode" == --unit ]]; then
    xcrun xctest -XCTest DemoControllerTests,DemoScriptTests,CommandOptionsTests,ConfigurationCLITests,DemoInputSourceTests build/Debug/CueTapTests.xctest \
        2>&1 | tee build/unit-test-output.log
else
    if pgrep -x cuetap >/dev/null; then
        printf '请先结束正在运行的 cuetap 进程，再执行原生集成测试，以免两份拦截器相互影响。\n' >&2
        exit 3
    fi
    build/Debug/cuetap --check
    xcrun xctest build/Debug/CueTapTests.xctest 2>&1 | tee build/test-output.log
    if /usr/bin/grep -Eq 'Test Case .* skipped' build/test-output.log; then
        printf '有原生测试因权限或图形会话条件被跳过，不能认定全部验收通过。\n' >&2
        exit 3
    fi
fi

xcodebuild -project CueTap.xcodeproj -scheme CueTap -configuration Release \
    -destination 'platform=macOS,arch=arm64' -derivedDataPath build/DerivedData -quiet build
printf '\n测试与 Release 构建通过。程序位置：%s/build/Release/cuetap\n' "$source_root"
