import Foundation

func report(_ message: String) {
    FileHandle.standardError.write(Data((message + "\n").utf8))
}

let options: CommandOptions
do {
    options = try CommandOptions(arguments: Array(CommandLine.arguments.dropFirst()),
                                 executableURL: Bundle.main.executableURL ?? URL(fileURLWithPath: CommandLine.arguments[0]))
} catch {
    report("CueTap：\(error)")
    exit(2)
}

do {
    switch options.mode {
    case .help:
        print("""
        CueTap：单位置键盘演示工具
        用法：cuetap [--script 文件路径]
              cuetap --validate [--script 文件路径]
              cuetap --check | --help
        未指定配置时，读取可执行文件旁的 html-demo.json。
        --validate  只校验配置并显示动作总数，不检查权限或拦截输入。
        --check     只检查输入监听、辅助功能权限与安全输入状态。
        配置仅在启动时读取，修改后需要重新启动；缺失或无效时直接退出。
        提前运行后，在编辑器中按 Cmd+Shift+R 开启或关闭演示。
        开启时自动切换 ABC/U.S.，关闭时恢复原输入源；按一下推进一步。
        完成后保持英文与输入拦截，直到热键关闭。
        结束进程：在启动终端按 Ctrl+C，或向进程发送 SIGTERM。
        """)
    case .check:
        try KeyboardSession.checkPermissions()
        print("权限检查通过。")
    case .validate, .run:
        let script = try DemoScript.load(from: options.scriptURL)
        print("配置已加载：\(script.name)，\(script.actions.count) 个动作。\n文件：\(options.scriptURL.path)")
        if options.mode == .run {
            let session = KeyboardSession(actions: script.actions)
            try session.run()
            if let failure = session.failure { report(failure); exit(1) }
        }
    }
} catch {
    report("CueTap：\(error)")
    exit(1)
}
