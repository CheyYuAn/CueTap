import AppKit

/// Text measurement and truncation, so titles are clipped here with an ellipsis rather than by AppKit.
extension StatusMenu {
    /// Width AppKit adds around a standard item title, minus the leading inset the labels repeat.
    static func trailingInset() -> CGFloat {
        let font = NSFont.menuFont(ofSize: 0)
        let probe = String(repeating: "N", count: 30)
        let text = (probe as NSString).size(withAttributes: [.font: font]).width
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: probe, action: nil, keyEquivalent: ""))
        return min(max(menu.size.width - text - Metrics.titleInset, 10), 30)
    }

    func width(of text: String, font: NSFont? = nil) -> CGFloat {
        (text as NSString).size(withAttributes: [.font: font ?? label.font ?? NSFont.menuFont(ofSize: 0)]).width
    }

    /// Tail truncation with an ellipsis, so a long name is shortened here rather than by AppKit,
    /// which would drop a whole word and leave no sign that anything is missing.
    func clip(_ text: String, to limit: CGFloat, font: NSFont? = nil) -> String {
        guard width(of: text, font: font) > limit else { return text }
        var head = text
        while !head.isEmpty {
            head.removeLast()
            let candidate = head + "…"
            if width(of: candidate, font: font) <= limit { return candidate }
        }
        return "…"
    }
}
