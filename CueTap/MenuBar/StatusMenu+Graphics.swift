import AppKit

/// Everything the menu draws itself: the status bar icon, the On/Off badge, list icons and shortcut glyphs.
extension StatusMenu {
    /// The status bar icon is a template image drawn from the symbol, the "interface icon" the
    /// HIG allows for a menu bar extra. Handing the symbol over with a point size baked in gets
    /// it clipped top and bottom by the status bar button's own symbol layout, the button's
    /// symbolConfiguration property is ignored there, and the bare symbol draws only 14 pt of
    /// glyph while pushing the button past the 22 pt strip. Drawn into an 18 pt image the glyph
    /// is 16 pt high, whole, and the button stays at the strip's height.
    static func statusImage(_ symbol: NSImage) -> NSImage {
        let source = symbol.withSymbolConfiguration(.init(scale: .large)) ?? symbol
        let height = Metrics.statusIconHeight
        let width = (source.size.width / source.size.height * height).rounded()
        let image = NSImage(size: NSSize(width: width, height: height), flipped: false) { bounds in
            source.draw(in: bounds)
            return true
        }
        image.isTemplate = true
        return image
    }

    /// Key combinations in the usual macOS order and glyphs, for example ⇧⌘R and ⌘ Click.
    static func symbols(_ shortcut: String) -> String {
        let glyphs = ["ctrl": "⌃", "control": "⌃", "option": "⌥", "alt": "⌥", "shift": "⇧", "cmd": "⌘", "command": "⌘"]
        var modifiers: Set<String> = []
        var key = ""
        for part in shortcut.lowercased().split(separator: "+").map(String.init) {
            if let glyph = glyphs[part] { modifiers.insert(glyph) } else { key = part }
        }
        let prefix = ["⌃", "⌥", "⇧", "⌘"].filter { modifiers.contains($0) }.joined()
        return prefix + (key == "click" ? " Click" : key.uppercased())
    }

    /// A switch row: plain title on the left and a rounded On/Off badge pushed to the right edge
    /// by a tab stop, the way a system menu shows a state a click will flip.
    func badgeTitle(_ text: String, _ state: String) -> NSAttributedString {
        let style = NSMutableParagraphStyle()
        style.tabStops = [NSTextTab(textAlignment: .right,
                                    location: rowWidth - Metrics.titleInset - trailing, options: [:])]
        let title = NSMutableAttributedString(string: text + "\t", attributes: [
            .font: NSFont.menuFont(ofSize: 0), .foregroundColor: NSColor.labelColor])
        let image = badge(state)
        let attachment = NSTextAttachment()
        attachment.image = image
        attachment.bounds = NSRect(x: 0, y: -4, width: image.size.width, height: image.size.height)
        title.append(NSAttributedString(attachment: attachment))
        title.addAttribute(.paragraphStyle, value: style, range: NSRange(location: 0, length: title.length))
        return title
    }

    func badge(_ text: String) -> NSImage {
        let font = NSFont.systemFont(ofSize: 11, weight: .medium)
        let size = (text as NSString).size(withAttributes: [.font: font])
        let box = NSSize(width: (size.width + 16).rounded(.up), height: 17)
        let image = NSImage(size: box)
        image.lockFocus()
        NSColor.tertiaryLabelColor.setFill()
        NSBezierPath(roundedRect: NSRect(origin: .zero, size: box),
                     xRadius: box.height / 2, yRadius: box.height / 2).fill()
        (text as NSString).draw(at: NSPoint(x: (box.width - size.width) / 2, y: (box.height - size.height) / 2),
                                withAttributes: [.font: font, .foregroundColor: NSColor.labelColor])
        image.unlockFocus()
        return image
    }

    /// An SF Symbol inside the title keeps the icon under this code's control: an item image is
    /// not drawn in this menu at all.
    func choiceTitle(_ symbol: String, _ text: String) -> NSAttributedString {
        let font = NSFont.menuFont(ofSize: 0)
        let title = NSMutableAttributedString()
        if let icon = tinted(symbol) {
            let attachment = NSTextAttachment()
            attachment.image = icon
            // The icon box is centred on the text's optical centre, half the cap height above
            // the baseline, so the symbol and the name sit on the same line.
            attachment.bounds = NSRect(x: 0, y: (font.capHeight - icon.size.height) / 2,
                                       width: icon.size.width, height: icon.size.height)
            title.append(NSAttributedString(attachment: attachment))
        }
        title.append(NSAttributedString(string: "  " + text, attributes: [
            .font: font, .foregroundColor: NSColor.labelColor]))
        return title
    }

    /// Template images are not tinted inside an attributed string, so the symbol is drawn once in
    /// the label colour. Each symbol has its own ink box, so the drawn pixels are centred in one
    /// square box: the names after the icons then share a left edge.
    func tinted(_ symbol: String) -> NSImage? {
        if let cached = icons[symbol] { return cached }
        guard let base = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)?
            .withSymbolConfiguration(.init(pointSize: Metrics.iconPoint, weight: .regular)) else { return nil }
        let ink = Self.inkBounds(base)
        let box = NSSize(width: Metrics.iconColumn, height: Metrics.iconColumn)
        let out = NSImage(size: box)
        out.lockFocus()
        base.draw(at: NSPoint(x: (box.width - ink.width) / 2 - ink.minX,
                              y: (box.height - ink.height) / 2 - ink.minY),
                  from: .zero, operation: .sourceOver, fraction: 1)
        NSColor.labelColor.set()
        NSRect(origin: .zero, size: box).fill(using: .sourceAtop)
        out.unlockFocus()
        icons[symbol] = out
        return out
    }

    /// The rectangle the symbol actually paints, in image coordinates. A symbol image carries its
    /// own padding, so centring the image is not the same as centring the glyph.
    static func inkBounds(_ image: NSImage) -> NSRect {
        let width = Int(ceil(image.size.width)), height = Int(ceil(image.size.height))
        let full = NSRect(origin: .zero, size: image.size)
        guard width > 0, height > 0,
              let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: width, pixelsHigh: height,
                                         bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                         colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)
        else { return full }
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        image.draw(at: .zero, from: .zero, operation: .sourceOver, fraction: 1)
        NSGraphicsContext.restoreGraphicsState()
        var minX = width, maxX = -1, minY = height, maxY = -1
        for y in 0..<height {
            for x in 0..<width where (rep.colorAt(x: x, y: y)?.alphaComponent ?? 0) > 0.05 {
                minX = min(minX, x); maxX = max(maxX, x)
                minY = min(minY, y); maxY = max(maxY, y)
            }
        }
        guard maxX >= minX, maxY >= minY else { return full }
        // Bitmap rows run from the top; the drawing origin runs from the bottom.
        return NSRect(x: CGFloat(minX), y: CGFloat(height - 1 - maxY),
                      width: CGFloat(maxX - minX + 1), height: CGFloat(maxY - minY + 1))
    }
}
