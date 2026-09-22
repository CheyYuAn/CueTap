import AppKit

/// Native AppKit menu and controls. Configuration choices expand inline, not in a submenu.
final class StatusMenu: NSObject, NSMenuDelegate {
    private let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let menu = NSMenu()
    private let stateRow = InfoRow("State: Off")
    private let advanceRow = InfoRow("Next segment")
    private let errorItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    private let configurationItem = NSMenuItem()
    private let loginItem = NSMenuItem(title: Metrics.loginTitle, action: #selector(toggleLogin), keyEquivalent: "")
    private let folderItem = NSMenuItem(title: Metrics.folderTitle, action: #selector(openConfigurationsFolder), keyEquivalent: "")
    private let stopItem = NSMenuItem(title: "Stop CueTap", action: #selector(stopDemo), keyEquivalent: "")
    private let row = NSView()
    private let disclosure = NSButton(title: "", target: nil, action: nil)
    let label = NSTextField(labelWithString: "Configuration")
    let trailing: CGFloat
    var rowWidth: CGFloat = Metrics.minWidth
    private var choiceItems: [NSMenuItem] = []
    var icons: [String: NSImage] = [:]
    private var expanded = false
    private var canSelect = true
    private let configurations: () throws -> [ConfigurationInfo]
    private let select: (String) -> ControlResponse
    private let openFolder: () -> Void
    private let loginEnabled: () -> Bool
    private let setLogin: (Bool) -> ControlResponse
    private let stop: () -> Void
    private let quit: () -> Void

    init(configurations: @escaping () throws -> [ConfigurationInfo], select: @escaping (String) -> ControlResponse,
         openFolder: @escaping () -> Void, loginEnabled: @escaping () -> Bool,
         setLogin: @escaping (Bool) -> ControlResponse, stop: @escaping () -> Void, quit: @escaping () -> Void) throws {
        self.configurations = configurations; self.select = select
        self.openFolder = openFolder; self.loginEnabled = loginEnabled; self.setLogin = setLogin
        self.stop = stop; self.quit = quit
        trailing = Self.trailingInset()
        guard let image = NSImage(systemSymbolName: "pointer.arrow.ipad.rays", accessibilityDescription: "CueTap") else {
            throw ControlError("missing_symbol", "The system symbol pointer.arrow.ipad.rays is unavailable.")
        }
        image.isTemplate = true
        super.init()
        menu.autoenablesItems = false
        menu.delegate = self
        errorItem.isEnabled = false
        errorItem.isHidden = true
        // The status and shortcut lines are custom views: a disabled item would be dimmed, and
        // these lines are ordinary text, not commands.
        menu.addItem(stateRow.item)
        menu.addItem(advanceRow.item)

        // A stock disclosure button inside an NSMenuItem view keeps menu tracking open.
        // There is no custom drawing or replacement panel/window.
        label.font = .menuFont(ofSize: 0)
        label.lineBreakMode = .byTruncatingTail
        disclosure.bezelStyle = .disclosure
        disclosure.setButtonType(.onOff)
        disclosure.target = self
        disclosure.action = #selector(toggleConfigurations)
        disclosure.setAccessibilityLabel("Expand configurations")
        row.addSubview(label)
        row.addSubview(disclosure)
        configurationItem.view = row
        layoutRows()
        menu.addItem(configurationItem)
        menu.addItem(errorItem)

        // Everything below lives in the menu from the start. A separator inserted while the menu
        // is open makes AppKit lay out the items around it against a stale width and cut their
        // titles, so only the configuration choices are ever inserted.
        menu.addItem(.separator())
        loginItem.target = self
        menu.addItem(loginItem)
        folderItem.target = self
        folderItem.attributedTitle = NSAttributedString(string: Metrics.folderTitle, attributes: [
            .font: NSFont.menuFont(ofSize: 0), .foregroundColor: NSColor.tertiaryLabelColor])
        menu.addItem(folderItem)
        menu.addItem(.separator())
        stopItem.target = self
        stopItem.isEnabled = false
        menu.addItem(stopItem)
        let quitItem = NSMenuItem(title: "Quit CueTap", action: #selector(exitProgram), keyEquivalent: "")
        quitItem.target = self
        menu.addItem(quitItem)
        item.menu = menu
        item.button?.image = Self.statusImage(image)
        item.button?.setAccessibilityLabel("CueTap")
    }

    func update(active: Bool, name: String, segment: Int, count: Int, hotkey: String, advance: String, canSelect: Bool) {
        self.canSelect = canSelect
        stateRow.label.stringValue = active ? "State: On" : "State: Off"
        stateRow.shortcut.stringValue = Self.symbols(hotkey)
        advanceRow.shortcut.stringValue = Self.symbols(advance)
        advanceRow.item.isHidden = count < 2
        stopItem.isEnabled = active
        let prefix = "Config: "
        let room = Metrics.maxWidth - Metrics.titleInset - Metrics.gap - Metrics.disclosureSize - trailing
        label.stringValue = prefix + clip(name, to: room - width(of: prefix))
        label.toolTip = name
        item.button?.toolTip = "CueTap \(active ? "on" : "off") · \(name) · \(segment)/\(count)"
        layoutRows()
        refreshLogin()
    }

    func menuWillOpen(_ menu: NSMenu) {
        refreshLogin()
        if expanded { rebuildChoices() }
    }

    /// The list always starts collapsed, so reopening the menu shows the short form.
    func menuDidClose(_ menu: NSMenu) {
        guard expanded else { return }
        expanded = false
        disclosure.state = .off
        disclosure.setAccessibilityLabel("Expand configurations")
        rebuildChoices()
    }

    /// Rows are as wide as their content, so a custom item cannot stretch the whole menu. All of
    /// them share one width so the shortcuts line up on the right.
    private func layoutRows() {
        let shortcutWidth = (max(width(of: stateRow.shortcut.stringValue), width(of: advanceRow.shortcut.stringValue)) + 4).rounded(.up)
        let rows = [stateRow, advanceRow].map {
            Metrics.titleInset + width(of: $0.label.stringValue) + Metrics.shortcutGap + shortcutWidth + Metrics.titleInset
        }
        let configuration = Metrics.titleInset + width(of: label.stringValue) + 6 + Metrics.gap
            + Metrics.disclosureSize + trailing
        // The commands below the list are plain items; matching their width keeps the shortcuts
        // flush with the right edge of the menu.
        let commands = Metrics.titleInset + width(of: Metrics.folderTitle) + trailing + Metrics.slack
        let width = min(max((rows + [configuration, commands]).max() ?? Metrics.minWidth, Metrics.minWidth), Metrics.maxWidth).rounded(.up)
        rowWidth = width
        stateRow.layout(width: width, shortcutWidth: shortcutWidth)
        advanceRow.layout(width: width, shortcutWidth: shortcutWidth)
        row.frame = NSRect(x: 0, y: 0, width: width, height: Metrics.rowHeight)
        disclosure.frame = NSRect(x: width - trailing - Metrics.disclosureSize,
                                  y: (Metrics.rowHeight - Metrics.disclosureSize) / 2,
                                  width: Metrics.disclosureSize, height: Metrics.disclosureSize)
        label.frame = NSRect(x: Metrics.titleInset, y: (Metrics.rowHeight - Metrics.labelHeight) / 2,
                             width: disclosure.frame.minX - Metrics.gap - Metrics.titleInset, height: Metrics.labelHeight)
    }

    @objc private func toggleConfigurations() {
        expanded.toggle()
        disclosure.state = expanded ? .on : .off
        disclosure.setAccessibilityLabel(expanded ? "Collapse configurations" : "Expand configurations")
        rebuildChoices()
    }

    private func rebuildChoices() {
        choiceItems.forEach { menu.removeItem($0) }
        choiceItems.removeAll()
        guard expanded else { return }
        if canSelect {
            do {
                let entries = try configurations()
                // Choices stay inside the width the menu already has: the window does not grow
                // once the list opens during tracking.
                let limit = rowWidth - Metrics.titleInset - trailing - Metrics.iconColumn
                    - Metrics.gap - Metrics.iconSlack
                for entry in entries {
                    let row = NSMenuItem(title: entry.name, action: #selector(selectConfiguration(_:)), keyEquivalent: "")
                    row.target = self
                    row.representedObject = entry.id
                    row.isEnabled = entry.error == nil
                    row.toolTip = entry.error ?? entry.description
                    row.attributedTitle = choiceTitle(entry.error == nil ? "keyboard" : "exclamationmark.triangle",
                                                      clip(entry.name, to: limit))
                    choiceItems.append(row)
                }
                if entries.isEmpty { addNote("No configurations") }
            } catch { addNote("Cannot read configurations: \(error)") }
        } else { addNote("Stop the demo to switch configurations") }
        let index = menu.index(of: configurationItem) + 1
        for (offset, row) in choiceItems.enumerated() { menu.insertItem(row, at: index + offset) }
    }

    private func addNote(_ text: String) {
        let row = NSMenuItem(title: clip(text, to: rowWidth - Metrics.titleInset - trailing - Metrics.slack), action: nil, keyEquivalent: "")
        row.isEnabled = false
        choiceItems.append(row)
    }

    private func report(_ response: ControlResponse, action: String) {
        errorItem.title = response.ok ? "" : clip("\(action) failed: \(response.message)",
                                                 to: rowWidth - Metrics.titleInset - trailing - Metrics.slack)
        errorItem.toolTip = response.ok ? nil : "\(action) failed: \(response.message)"
        errorItem.isHidden = response.ok
    }

    @objc private func selectConfiguration(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? String else { return }
        report(select(id), action: "Selection")
    }
    @objc private func toggleLogin() {
        report(setLogin(!loginEnabled()), action: "Launch at Login")
        refreshLogin()
    }

    private func refreshLogin() {
        loginItem.attributedTitle = badgeTitle(Metrics.loginTitle, loginEnabled() ? "On" : "Off")
    }
    @objc private func openConfigurationsFolder() { openFolder() }
    @objc private func stopDemo() { stop() }
    @objc private func exitProgram() { quit() }
    deinit { NSStatusBar.system.removeStatusItem(item) }
}
