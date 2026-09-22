import AppKit

/// Layout constants and titles shared by the menu, its custom rows and the drawing helpers.
extension StatusMenu {
    /// Row metrics for the custom-view items. AppKit draws standard items itself but hands a
    /// custom view the bare item rect, so those views repeat the leading inset AppKit uses for a
    /// title. No item in this menu carries a checkmark or state image, which would add a column
    /// and push every title sideways. `trailing` is measured from a probe menu at launch.
    enum Metrics {
        static let rowHeight: CGFloat = 24
        static let statusIconHeight: CGFloat = 18
        static let titleInset: CGFloat = 14
        static let labelHeight: CGFloat = 18
        static let disclosureSize: CGFloat = 16
        static let gap: CGFloat = 10
        static let shortcutGap: CGFloat = 24
        static let minWidth: CGFloat = 240
        static let maxWidth: CGFloat = 320
        static let iconPoint: CGFloat = 13
        /// Every list icon is drawn centred in a square of this size, so names keep one left edge
        /// whatever the symbol's own ink box is.
        static let iconColumn: CGFloat = 16
        /// Spare width kept clear of AppKit's own truncation, which drops a whole trailing word
        /// instead of clipping with an ellipsis. Titles carrying an icon need the wider margin.
        static let slack: CGFloat = 16
        static let iconSlack: CGFloat = 30
        static let folderTitle = "Open Configurations Folder"
        static let loginTitle = "Launch at Login"
    }
}
