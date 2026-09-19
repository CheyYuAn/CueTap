import Foundation

/// Owns imported configuration files. Only called by the resident process while playback is off.
struct ConfigurationStore {
    let paths: RuntimePaths

    struct Selection {
        let url: URL
        let script: DemoScript
        let settings: RuntimeSettings
    }

    func select(from source: URL, settings: RuntimeSettings) throws -> Selection {
        try select(DemoScript.readFile(from: source), from: source, settings: settings)
    }

    func select(_ file: DemoScript.File, from source: URL, settings: RuntimeSettings) throws -> Selection {
        try paths.prepareConfigurations()
        let resolvedSource = source.resolvingSymlinksInPath().standardizedFileURL
        let folder = paths.configurations.resolvingSymlinksInPath().standardizedFileURL
        let destination: URL
        var created = false
        if resolvedSource.deletingLastPathComponent().path == folder.path {
            destination = resolvedSource
        } else {
            destination = availableURL(for: source, data: file.data)
            if !FileManager.default.fileExists(atPath: destination.path) {
                try file.data.write(to: destination, options: .atomic)
                created = true
            }
        }
        do {
            try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: destination.path)
            var next = settings
            next.configurationPath = destination.path
            try paths.save(next)
            return Selection(url: destination, script: file.script, settings: next)
        } catch {
            // A failed selection must not leave a new orphan or replace the previous selection.
            if created { try? FileManager.default.removeItem(at: destination) }
            throw error
        }
    }

    private func availableURL(for source: URL, data: Data) -> URL {
        // Keep filenames recognizable and leave room for a collision suffix on the filesystem.
        let stem = String(String.UnicodeScalarView(source.deletingPathExtension().lastPathComponent.unicodeScalars.prefix(40)))
        let base = stem.isEmpty ? "configuration" : stem
        var index = 1
        while true {
            let suffix = index == 1 ? "" : "-\(index)"
            let candidate = paths.configurations.appendingPathComponent("\(base)\(suffix).json")
            let attributes = try? FileManager.default.attributesOfItem(atPath: candidate.path)
            if attributes == nil { return candidate }
            if attributes?[.type] as? FileAttributeType == .typeRegular,
               let existing = try? DemoScript.readFile(from: candidate), existing.data == data {
                return candidate
            }
            index += 1
        }
    }
}
