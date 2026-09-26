import Foundation

struct ShelfFile: Identifiable, Equatable {
    let url: URL
    var id: String { url.path }
    var name: String { url.lastPathComponent }
}

/// Session-only file references. No persistence, copying, moving, or deletion.
struct TemporaryFileShelf {
    struct AddResult {
        var added = 0
        var duplicates = 0
        var rejected = 0
    }

    private(set) var files: [ShelfFile] = []

    mutating func add(_ urls: [URL]) -> AddResult {
        var result = AddResult()
        var existing = Set(files.map(\.id))
        for url in urls {
            guard url.isFileURL else { result.rejected += 1; continue }
            let normalized = url.standardizedFileURL
            guard FileManager.default.isReadableFile(atPath: normalized.path) else {
                result.rejected += 1
                continue
            }
            guard existing.insert(normalized.path).inserted else {
                result.duplicates += 1
                continue
            }
            files.append(ShelfFile(url: normalized))
            result.added += 1
        }
        return result
    }

    mutating func remove(id: String) { files.removeAll { $0.id == id } }
    mutating func clear() { files.removeAll() }
}
