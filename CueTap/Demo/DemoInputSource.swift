import Carbon
import Foundation

/// Keep input-source ownership separate from playback and Quartz key emission.
protocol InputSourceAccess {
    func currentID() throws -> String
    func englishID() throws -> String
    func select(_ identifier: String) throws
}

struct SystemInputSourceAccess: InputSourceAccess {
    private func identifier(_ source: TISInputSource) -> String? {
        guard let value = TISGetInputSourceProperty(source, kTISPropertyInputSourceID) else { return nil }
        return Unmanaged<CFString>.fromOpaque(value).takeUnretainedValue() as String
    }

    private func enabledSource(_ id: String) -> TISInputSource? {
        let filter = [kTISPropertyInputSourceID as String: id] as CFDictionary
        guard let list = TISCreateInputSourceList(filter, false)?.takeRetainedValue() as? [TISInputSource] else { return nil }
        return list.first
    }

    func currentID() throws -> String {
        guard let source = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue(),
              let id = identifier(source) else {
            throw SessionError.unavailable("无法读取当前输入源，未开启演示。")
        }
        return id
    }

    func englishID() throws -> String {
        // Both match the physical US keycodes used by KeyboardOutput.
        // An arbitrary ASCII-capable layout could be Dvorak or AZERTY.
        for id in ["com.apple.keylayout.ABC", "com.apple.keylayout.US"] {
            if enabledSource(id) != nil { return id }
        }
        throw SessionError.unavailable("未找到已启用的 ABC 或 U.S. 输入源。请先在系统设置中添加，再开启演示。")
    }

    func select(_ identifier: String) throws {
        guard let source = enabledSource(identifier), TISSelectInputSource(source) == noErr,
              try currentID() == identifier else {
            throw SessionError.unavailable("无法切换输入源：\(identifier)。")
        }
    }
}

final class DemoInputSource {
    private let access: InputSourceAccess
    private var originalID: String?
    private var forcedID: String?

    init(access: InputSourceAccess = SystemInputSourceAccess()) { self.access = access }

    func synchronize(active: Bool) throws {
        guard active else { try restore(); return }
        if originalID == nil {
            let original = try access.currentID()
            let english = try access.englishID()
            originalID = original
            forcedID = english
        }
        if let forcedID, try access.currentID() != forcedID { try access.select(forcedID) }
    }

    func restore() throws {
        guard let originalID else { return }
        do {
            if try access.currentID() != originalID { try access.select(originalID) }
        } catch {
            // Keep the snapshot so shutdown cleanup can retry instead of losing it.
            throw SessionError.unavailable("恢复原输入源失败（\(originalID)）：\(error)")
        }
        self.originalID = nil
        forcedID = nil
    }

    deinit { try? restore() }
}
