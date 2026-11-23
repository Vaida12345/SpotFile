//
//  SpotFileTests.swift
//  SpotFileTests
//
//  Created by Vaida on 2026-09-21.
//

import Foundation
import FinderItem
import SwiftData
import Testing
@testable import SpotFile

@Suite(.serialized)
@MainActor
struct FileSearcherTests {

    @Test
    func exactMatchReturnsMatchingItem() async throws {
        let item = QueryItem(query: "Safari", item: .homeDirectory, openableFileRelativePath: "")
        let result = try await search(text: "safari", items: [item])

        guard case let .direct(matches)? = result.match else {
            Issue.record("Expected a direct search result.")
            return
        }

        #expect(matches.count == 1)
        #expect(matches.first?.0.id == item.id)
        #expect(matches.first?.1.isPrimary == true)
    }

    @Test
    func unmatchedTextReturnsEmptyDirectResults() async throws {
        let item = QueryItem(query: "Safari", item: .homeDirectory, openableFileRelativePath: "")
        let result = try await search(text: "unmatched-query", items: [item])

        guard case let .direct(matches)? = result.match else {
            Issue.record("Expected direct search results.")
            return
        }

        #expect(matches.isEmpty)
    }

    @Test
    func emptyTextResetsSearchState() async throws {
        let result = try await search(text: "", items: [])

        #expect(result.options.contains(.reset))
        #expect(result.match == nil)
    }

    @Test
    func existingAbsolutePathReturnsGoToResult() async throws {
        let result = try await search(text: NSHomeDirectory(), items: [])

        guard case let .goto(item, match)? = result.match else {
            Issue.record("Expected a Go To result for the home directory.")
            return
        }

        #expect(item.item.path == NSHomeDirectory())
        #expect(match.isPrimary == true)
    }

    @Test
    func exactMatchRanksAheadOfPartialMatches() async throws {
        let items = (0..<10).map { index in
            QueryItem(query: "Project\(index)", item: .homeDirectory, openableFileRelativePath: "")
        }
        let result = try await search(text: "Project5", items: items)

        guard case let .direct(matches)? = result.match else {
            Issue.record("Expected direct search results.")
            return
        }

        let first = try #require(matches.first)
        #expect(first.0.query.content == "Project5")
    }

    @Test
    func explicitDeepSearchReturnsMatchingChild() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("SpotFileTests-\(UUID().uuidString)", isDirectory: true)
        let childDirectory = directory.appendingPathComponent("Reports", isDirectory: true)
        try FileManager.default.createDirectory(at: childDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let item = QueryItem(query: "Workspace", item: FinderItem(at: directory.path), openableFileRelativePath: "")
        item.childOptions = .init(isDirectory: true, isEnabled: true, includeFolder: true, includeFile: false, enumeration: true)

        let result = try await search(text: " reports", parent: item, items: [item])

        guard case let .deep(target, _, matches)? = result.match else {
            Issue.record("Expected deep search results.")
            return
        }

        #expect(target.id == item.id)
        #expect(matches.contains { $0.0.item.name == "Reports" })
    }

    /// When typing fast, the previous complete search may already contain part of the deep search text. The target query must still end at the whitespace, not at the end of the previous request.
    @Test
    func deepSearchSplitsAtWhitespaceWhenPreviousRequestOvershoots() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("SpotFileTests-\(UUID().uuidString)", isDirectory: true)
        let childDirectory = directory.appendingPathComponent("Reports", isDirectory: true)
        try FileManager.default.createDirectory(at: childDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let item = QueryItem(query: "Workspace", item: FinderItem(at: directory.path), openableFileRelativePath: "")
        item.childOptions = .init(isDirectory: true, isEnabled: true, includeFolder: true, includeFile: false, enumeration: true)

        let match = try #require(item.match(lowercasedQueryChars: Array("workspace")))
        let previous = FileSearcher.SearchState(
            request: FileSearcher.SearchRequest(text: "workspace re", parent: nil),
            match: .direct([(item, match)]),
            options: []
        )

        let result = try await search(text: "workspace rep", previous: previous, items: [item])

        guard case let .deep(target, targetQuery, matches)? = result.match else {
            Issue.record("Expected deep search results.")
            return
        }

        #expect(target.id == item.id)
        #expect(targetQuery == "workspace")
        #expect(matches.contains { $0.0.item.name == "Reports" })
    }

    @Test
    func deepSearchBoundaryPrefersLastWhitespaceWithinPreviousRequest() {
        let item = QueryItem(query: "Workspace", item: .homeDirectory, openableFileRelativePath: "")

        #expect(FileSearcher.deepSearchBoundary(in: Array("workspace rep"), target: item, preferredEnd: 12) == 9)
        #expect(FileSearcher.deepSearchBoundary(in: Array("workspace rep"), target: item, preferredEnd: 4) == 9)
        #expect(FileSearcher.deepSearchBoundary(in: Array("unrelated rep"), target: item, preferredEnd: 12) == nil)
    }

    private func search(
        text: String,
        parent: QueryItem? = nil,
        previous: FileSearcher.SearchState? = nil,
        items: [QueryItem]
    ) async throws -> FileSearcher.SearchState {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: QueryChildRecord.self, configurations: configuration)

        nonisolated(unsafe) let request = FileSearcher.SearchRequest(text: text, parent: parent)
        nonisolated(unsafe) let context = container.mainContext
        nonisolated(unsafe) let searchItems = items
        nonisolated(unsafe) let previous = previous

        return try await FileSearcher.performSearches(
            request: request,
            previous: previous,
            context: context,
            in: searchItems
        )
    }
}
