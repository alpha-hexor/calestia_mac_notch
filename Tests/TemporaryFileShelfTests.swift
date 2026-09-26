import XCTest
@testable import CaelestiaCore

final class TemporaryFileShelfTests: XCTestCase {
    private var directory: URL!
    private var first: URL!
    private var second: URL!

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        first = directory.appendingPathComponent("first.txt")
        second = directory.appendingPathComponent("second.txt")
        try Data("first fixture".utf8).write(to: first)
        try Data("second fixture".utf8).write(to: second)
    }

    override func tearDownWithError() throws { try FileManager.default.removeItem(at: directory) }

    func testMultiFileDropDeduplicatesAndKeepsOriginalURLs() {
        var shelf = TemporaryFileShelf()
        let result = shelf.add([first, second, first])
        XCTAssertEqual(result.added, 2)
        XCTAssertEqual(result.duplicates, 1)
        XCTAssertEqual(shelf.files.map(\.url), [first, second])
        XCTAssertEqual(shelf.add([first]).added, 0)
    }

    func testRemoveAndClearNeverDeleteOrModifyOriginals() throws {
        var shelf = TemporaryFileShelf()
        _ = shelf.add([first, second])
        shelf.remove(id: first.path)
        XCTAssertEqual(shelf.files.map(\.url), [second])
        shelf.clear()
        XCTAssertTrue(shelf.files.isEmpty)
        XCTAssertEqual(try Data(contentsOf: first), Data("first fixture".utf8))
        XCTAssertEqual(try Data(contentsOf: second), Data("second fixture".utf8))
    }

    func testOnlyReadableLocalItemsAreAcceptedIncludingFolders() {
        var shelf = TemporaryFileShelf()
        let result = shelf.add([directory, directory.appendingPathComponent("missing.txt"), URL(string: "https://example.com/file")!])
        XCTAssertEqual(result.added, 1)
        XCTAssertEqual(result.rejected, 2)
        XCTAssertEqual(shelf.files.first?.url, directory.standardizedFileURL)
    }

    func testNewSessionIsEmptyAndFileContentsAreNotSnapshotted() throws {
        var shelf = TemporaryFileShelf()
        _ = shelf.add([first])
        try Data("updated fixture".utf8).write(to: first)
        XCTAssertEqual(try Data(contentsOf: shelf.files[0].url), Data("updated fixture".utf8))
        XCTAssertTrue(TemporaryFileShelf().files.isEmpty)
    }
}
