import XCTest
import SwiftUI
import SwiftData
import FinderItem
@testable import SpotFile

final class SpotFileTests: XCTestCase {

    static let modelContext: ModelContext = {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: QueryChildRecord.self, configurations: config)
        return container.mainContext
    }()

    /// Wait for the detached task spawned by `updateSearches` to finish.
    func waitForSearch(_ provider: ModelProvider, timeout: TimeInterval = 30.0) {
        guard let task = provider.previous.task else { return }
        let expectation = expectation(description: "search completes")
        Task { try? await task.value; expectation.fulfill() }
        wait(for: [expectation], timeout: timeout)
    }

    // MARK: - Correctness

    func testExactMatch_singleItem() {
        let provider = ModelProvider()
        provider.items = [
            QueryItem(query: "Safari", item: FinderItem(at: "/Applications/Safari.app"), openableFileRelativePath: "")
        ]
        provider.searchText = "safari"

        provider.updateSearches(context: Self.modelContext)
        waitForSearch(provider)

        XCTAssertFalse(provider.matches.isEmpty)
        XCTAssertEqual(provider.matches.first?.1.query.content, "Safari")
    }

    func testNoMatch_emptyItems_goesToPath() {
        let provider = ModelProvider()
        provider.items = []
        provider.searchText = "/Applications"

        provider.updateSearches(context: Self.modelContext)
        waitForSearch(provider)

        XCTAssertFalse(provider.matches.isEmpty)
        XCTAssertTrue(provider.matches.first?.1 is GoToItem)
    }

    func testNoMatch_withItems_goesToPath() {
        let provider = ModelProvider()
        provider.items = [
            QueryItem(query: "Unrelated", item: FinderItem(at: "/tmp/nonexistent"), openableFileRelativePath: "")
        ]
        provider.searchText = "/Applications"

        provider.updateSearches(context: Self.modelContext)
        waitForSearch(provider)

        XCTAssertFalse(provider.matches.isEmpty)
        XCTAssertTrue(provider.matches.first?.1 is GoToItem)
    }

    func testEmptySearch_resetsState() {
        let provider = ModelProvider()
        provider.items = [QueryItem.new()]
        provider.searchText = "test"
        provider.selectionIndex = 5
        provider.shownStartIndex = 3
        provider.matches = [(0, QueryItem.preview, QueryItem.Match(text: Text(verbatim: "x"), isPrimary: true))]

        provider.searchText = ""
        provider.updateSearches(context: Self.modelContext)
        waitForSearch(provider)

        XCTAssertEqual(provider.matches.count, 0)
        XCTAssertEqual(provider.selectionIndex, 0)
        XCTAssertEqual(provider.shownStartIndex, 0)
    }

    func testPartialMatch_jumpMatch() {
        let provider = ModelProvider()
        provider.items = [
            QueryItem(query: "Xcode", item: FinderItem(at: "/Applications/Xcode.app"), openableFileRelativePath: "")
        ]
        provider.searchText = "xc" // jump-match (abbreviation-style)

        provider.updateSearches(context: Self.modelContext)
        waitForSearch(provider)

        XCTAssertFalse(provider.matches.isEmpty)
    }

    func testNoMatch_nonExistentPath_returnsEmpty() {
        let provider = ModelProvider()
        provider.items = []
        provider.searchText = "xyznonexistent123"

        provider.updateSearches(context: Self.modelContext)
        waitForSearch(provider)

        XCTAssertEqual(provider.matches.count, 0)
    }

    func testMultipleItems_bestMatchFirst() {
        let items = (0..<20).map { i in
            QueryItem(query: "Project\(i)", item: FinderItem(at: "/tmp/bench/p\(i)"), openableFileRelativePath: "")
        }
        let provider = ModelProvider()
        provider.items = items
        provider.searchText = "Project5"

        provider.updateSearches(context: Self.modelContext)
        waitForSearch(provider)

        XCTAssertFalse(provider.matches.isEmpty)
        // "Project5" should appear first (exact content match sorts highest)
        let topQuery = provider.matches.first?.1.query.content ?? ""
        XCTAssertEqual(topQuery, "Project5")
    }

    // MARK: - Benchmarks

    func testBenchmark_matchScaling_10_items() {
        bench(items: 10, search: "Item0", iterations: 5)
    }

    func testBenchmark_matchScaling_50_items() {
        bench(items: 50, search: "Item24", iterations: 5)
    }

    func testBenchmark_matchScaling_100_items() {
        bench(items: 100, search: "Item49", iterations: 5)
    }

    func testBenchmark_matchScaling_500_items() {
        bench(items: 500, search: "Item249", iterations: 3)
    }

    func testBenchmark_allMatch_manyResults() {
        // Query that matches everything — exercises the full sort path
        bench(items: 200, search: "Item", iterations: 3)
    }

    func testBenchmark_warmSearch() {
        // Simulate warm search: previous results exist, search narrows down.
        // This is the fast path (line 104: canUseLastResult).
        let items = (0..<100).map { i in
            QueryItem(query: "Project\(i)", item: FinderItem(at: "/tmp/bench/p\(i)"), openableFileRelativePath: "")
        }
        let provider = ModelProvider()
        provider.items = items

        // First search — populates previous
        provider.searchText = "Project"
        provider.updateSearches(context: Self.modelContext)
        waitForSearch(provider)

        // Second search — narrows previous results (warm path)
        measure {
            provider.searchText = "Project5"
            provider.updateSearches(context: Self.modelContext)
            waitForSearch(provider)
        }
    }

    func testBenchmark_coldSearch() {
        // Cold search: no previous state, full scan of all items.
        // This is the slow path (line 104: canUseLastResult = false).
        let items = (0..<200).map { i in
            QueryItem(query: "Project\(i)", item: FinderItem(at: "/tmp/bench/p\(i)"), openableFileRelativePath: "")
        }

        measure {
            let provider = ModelProvider()
            provider.items = items
            provider.searchText = "Project99"
            provider.updateSearches(context: Self.modelContext)
            waitForSearch(provider)
        }
    }

    // MARK: - Helpers

    /// Create a provider with `count` fake items, run a search, and print timing.
    private func bench(items count: Int, search query: String, iterations: Int) {
        let items = (0..<count).map { i in
            QueryItem(query: "Item\(i)", item: FinderItem(at: "/tmp/spotfile-bench/\(i)"), openableFileRelativePath: "")
        }

        var timings: [TimeInterval] = []
        timings.reserveCapacity(iterations)

        for _ in 0..<iterations {
            let provider = ModelProvider()
            provider.items = items
            provider.searchText = query

            let start = Date()
            provider.updateSearches(context: Self.modelContext)
            waitForSearch(provider)
            timings.append(Date().timeIntervalSince(start))
        }

        let avg = timings.reduce(0, +) / Double(timings.count)
        let min = timings.min()!
        let max = timings.max()!
        print("[BENCH] \(count) items × \(iterations) runs — avg: \(String(format: "%.1f", avg * 1000))ms  min: \(String(format: "%.1f", min * 1000))ms  max: \(String(format: "%.1f", max * 1000))ms  matches: \(count)")
    }
}
