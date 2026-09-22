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
            throw SessionError.unavailable("Cannot read the current input source. Demo was not enabled.")
        }
        return id
    }

    func englishID() throws -> String {
        // Both match the physical US keycodes used by KeyboardOutput.
        // An arbitrary ASCII-capable layout could be Dvorak or AZERTY.
        for id in ["com.apple.keylayout.ABC", "com.apple.keylayout.US"] {
            if enabledSource(id) != nil { return id }
        }
        throw SessionError.unavailable("No enabled ABC or U.S. input source. Add one in System Settings before enabling a demo.")
    }

    func select(_ identifier: String) throws {
        guard let source = enabledSource(identifier), TISSelectInputSource(source) == noErr,
              try currentID() == identifier else {
            throw SessionError.unavailable("Cannot select input source: \(identifier).")
        }
    }
}
