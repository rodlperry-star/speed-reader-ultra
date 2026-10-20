import Foundation

/// Remembers one folder the person picked (usually iCloud Drive → Speed Reader) and
/// finds books in it that haven't been imported yet.
enum FolderSync {
    private static let bookmarkKey = "syncFolderBookmark"
    private static let importedKey = "syncFolderImported"
    static let bookTypes: Set<String> = ["epub", "pdf", "txt"]

    struct Candidate: Sendable {
        let url: URL
        let name: String
        let key: String
    }

    // MARK: Saved folder

    static func save(folder url: URL) throws {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        let data = try url.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil)
        UserDefaults.standard.set(data, forKey: bookmarkKey)
    }

    static func savedFolder() -> URL? {
        guard let data = UserDefaults.standard.data(forKey: bookmarkKey) else { return nil }
        var stale = false
        guard let url = try? URL(resolvingBookmarkData: data, options: [], relativeTo: nil, bookmarkDataIsStale: &stale) else { return nil }
        if stale { try? save(folder: url) }
        return url
    }

    static func forget() {
        UserDefaults.standard.removeObject(forKey: bookmarkKey)
    }

    private static var imported: Set<String> {
        get { Set(UserDefaults.standard.stringArray(forKey: importedKey) ?? []) }
        set { UserDefaults.standard.set(Array(newValue), forKey: importedKey) }
    }

    static func markImported(_ keys: [String]) {
        var s = imported
        keys.forEach { s.insert($0) }
        imported = s
    }

    // MARK: Scan

    /// Lists books in the folder that haven't been imported yet. Doesn't read them.
    static func candidates(in folder: URL) -> (items: [Candidate], waiting: Int, error: String?) {
        let scoped = folder.startAccessingSecurityScopedResource()
        defer { if scoped { folder.stopAccessingSecurityScopedResource() } }

        let fm = FileManager.default
        let keys: [URLResourceKey] = [.fileSizeKey, .isDirectoryKey, .ubiquitousItemDownloadingStatusKey]
        let entries: [URL]
        do {
            entries = try fm.contentsOfDirectory(at: folder, includingPropertiesForKeys: keys, options: [])
        } catch {
            return ([], 0, "Couldn’t open the sync folder. Choose it again in the Library.")
        }
        let done = imported
        var items: [Candidate] = []
        var waiting = 0
        for entry in entries {
            var url = entry
            var name = entry.lastPathComponent
            // Older iCloud placeholders look like ".Book Title.epub.icloud"
            if name.hasPrefix("."), name.hasSuffix(".icloud") {
                name = String(name.dropFirst().dropLast(".icloud".count))
                url = folder.appendingPathComponent(name)
                if bookTypes.contains(url.pathExtension.lowercased()) {
                    try? fm.startDownloadingUbiquitousItem(at: url)
                    waiting += 1
                }
                continue
            }
            if name.hasPrefix(".") { continue }
            guard bookTypes.contains(url.pathExtension.lowercased()) else { continue }
            let values = try? url.resourceValues(forKeys: Set(keys))
            if values?.isDirectory == true { continue }
            if let status = values?.ubiquitousItemDownloadingStatus, status != .current {
                try? fm.startDownloadingUbiquitousItem(at: url)
                waiting += 1
                continue
            }
            let key = "\(name)|\(values?.fileSize ?? 0)"
            if !done.contains(key) { items.append(Candidate(url: url, name: name, key: key)) }
        }
        items.sort { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        return (items, waiting, nil)
    }

    /// Reads one book. Runs off the main thread.
    static func read(_ item: Candidate, in folder: URL) -> Data? {
        let scoped = folder.startAccessingSecurityScopedResource()
        defer { if scoped { folder.stopAccessingSecurityScopedResource() } }
        var data: Data?
        var coordError: NSError?
        NSFileCoordinator().coordinate(readingItemAt: item.url, options: [], error: &coordError) { readURL in
            data = try? Data(contentsOf: readURL)
        }
        return data
    }
}
