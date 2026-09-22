import Foundation
import Darwin

struct RuntimeSettings: Codable {
    var configurationPath: String?
    var hotkey = DemoHotkey.default.label
    var advanceShortcut = SegmentAdvanceShortcut.default.label

    enum CodingKeys: String, CodingKey { case configurationPath, hotkey, advanceShortcut }
    init(configurationPath: String? = nil, hotkey: String = DemoHotkey.default.label,
         advanceShortcut: String = SegmentAdvanceShortcut.default.label) {
        self.configurationPath = configurationPath; self.hotkey = hotkey; self.advanceShortcut = advanceShortcut
    }
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        configurationPath = try values.decodeIfPresent(String.self, forKey: .configurationPath)
        hotkey = try values.decodeIfPresent(String.self, forKey: .hotkey) ?? DemoHotkey.default.label
        advanceShortcut = try values.decodeIfPresent(String.self, forKey: .advanceShortcut) ?? SegmentAdvanceShortcut.default.label
    }
}
