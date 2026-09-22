import Carbon
import Foundation

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
            throw SessionError.unavailable("Could not restore input source (\(originalID)): \(error)")
        }
        self.originalID = nil
        forcedID = nil
    }

    deinit { try? restore() }
}
