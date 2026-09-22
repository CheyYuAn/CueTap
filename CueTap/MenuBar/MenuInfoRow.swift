import AppKit

/// The two text-only rows at the top of the menu.
extension StatusMenu {
    /// A text-only menu row: plain text on the left and, for the shortcut rows, the key
    /// combination on the right, the way AppKit lays out a key equivalent.
    final class InfoRow {
        let view = NSView()
        let label = NSTextField(labelWithString: "")
        let shortcut = NSTextField(labelWithString: "")
        let item = NSMenuItem()

        init(_ text: String) {
            label.stringValue = text
            label.font = .menuFont(ofSize: 0)
            label.textColor = .labelColor
            label.lineBreakMode = .byTruncatingTail
            shortcut.font = .menuFont(ofSize: 0)
            shortcut.textColor = .secondaryLabelColor
            shortcut.alignment = .right
            view.addSubview(label)
            view.addSubview(shortcut)
            item.view = view
        }

        func layout(width: CGFloat, shortcutWidth: CGFloat) {
            view.frame = NSRect(x: 0, y: 0, width: width, height: Metrics.rowHeight)
            let y = (Metrics.rowHeight - Metrics.labelHeight) / 2
            shortcut.frame = NSRect(x: width - Metrics.titleInset - shortcutWidth, y: y,
                                    width: shortcutWidth, height: Metrics.labelHeight)
            label.frame = NSRect(x: Metrics.titleInset, y: y,
                                 width: shortcut.frame.minX - Metrics.shortcutGap - Metrics.titleInset,
                                 height: Metrics.labelHeight)
        }
    }
}
