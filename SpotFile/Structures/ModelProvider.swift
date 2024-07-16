//
//  ModelProvider.swift
//  SpotFile
//
//  Created by Vaida on 2024/2/4.
//

import Foundation
import Stratum
import SwiftUI
import UniformTypeIdentifiers
import ConcurrentStream
import SwiftData
import OSLog


@Observable
final class ModelProvider: Codable, DataProvider, UndoTracking {
    
    var items: [QueryItem] = [] {
        didSet {
            selectionIndex = 0
            matches.removeAll()
        }
    }
    
    @ObservationIgnored
    var previous = PreviousState()
    
    var searchText: String = ""
    
    var selectionIndex: Int = 0
    
    var shownStartIndex: Int = 0
    
    var matches: [(Int, any QueryItemProtocol, QueryItem.Match)] = []
    
    var isSearching = false
    
    
    func reset() {
        self.searchText.removeAll()
        self.selectionIndex = 0
        self.shownStartIndex = 0
        self.isSearching = false
        
        self.previous.reset()
        self.matches.removeAll()
    }
    
    func updateSearches(context: ModelContext) {
        guard !searchText.isEmpty else { self.reset(); return }
        
        let logger = Logger(subsystem: "app.Vaida.spotFile", category: #function)
        let _startDate = Date()
        logger.trace("start to search for \"\(self.searchText)\"")
        
        nonisolated(unsafe)
        let previous = previous // cross actor.
        nonisolated(unsafe)
        let searchText = searchText
        nonisolated(unsafe)
        let previousSearchText = previous.searchText
        nonisolated(unsafe)
        let context = context
        nonisolated(unsafe)
        let items = items
        
        isSearching = true
        self.selectionIndex = 0
        
        let canUseLastResult = searchText.hasPrefix(previousSearchText) && previous.task == nil
        previous.task?.cancel()
        // Can now safely discard the previous task. As before the task could make any changes, on the main actor, it must had checked for cancelation. During execution, no suspension point was provided, hence such transaction would be completed before the next one can run.
        
        previous.task = Task.detached {
            func onComplete() async throws {
                logger.trace("searching \"\(searchText)\" completed within \(_startDate.distanceToNow())")
                
                previous.searchText = searchText
                previous.task = nil
                
                try await MainActor.run {
                    try Task.checkCancellation()
                    self.isSearching = false
                }
            }
            
            if searchText.count < previousSearchText.count {
                // is deleting, then wait for a sec before conducting any search
                try await Task.sleep(for: .milliseconds(50))
            }
            try Task.checkCancellation()
            
            let total = !previousSearchText.isEmpty && canUseLastResult ? previous.matches : items
            
            let itemsMatches: [(QueryItem, QueryItem.Match)] = if previous.parentQuery != nil {
                []
            } else {
                try await total.stream.compactMap { item in
                    try Task.checkCancellation()
                    
                    if let string = try await ModelProvider._check(item: item, searchText: searchText, context: context) {
                        return (item, string)
                    } else {
                        return nil
                    }
                }.sequence.sorted(on: {
                    if $0.0.query.content.lowercased() == searchText.lowercased() {
                        return Int.max
                    } else {
                        return ($0.0.openedRecords.filter({ $0.key.hasPrefix(searchText) }).map(\.value).max() ?? 0) << 32 | (Int(UInt32.max) - $0.0.query.content.count)
                    }
                }, by: >)
            }
            
            func exitWithoutDeepSearch() async throws {
                logger.trace("not perform deep search for \"\(searchText)\", exit with current match count: \(itemsMatches.count), previous match count: \(previous.matches.count)")
                
                var matchesIsUpdated = false
                if itemsMatches.isEmpty {
                    func set(goto: String) async throws {
                        let item = FinderItem(at: goto)
                        let itemIsExist = item.exists
                        
                        if itemIsExist {
                            try await MainActor.run {
                                try Task.checkCancellation()
                                self.matches = [(0, GoToItem(item: item, iconSystemName: ""), QueryItem.Match(text: Text("goto: ") + Text(item.name).bold(), isPrimary: true))]
                            }
                            
                            matchesIsUpdated = true
                        }
                    }
                    
                    if searchText.starts(with: "/") {
                        try await set(goto: searchText)
                    } else if searchText.starts(with: "~") {
                        try await set(goto: searchText.replacing(/^~/, with: NSHomeDirectory()))
                    } else if searchText.hasPrefix("file:") {
                        try await set(goto: "/" + searchText.dropFirst(5).dropFirst(while: { $0 == "/" }))
                    } else if "NSHomeDirectory()".starts(with: searchText) {
                        let item = FinderItem.homeDirectory.appending(path: "/Library/Containers/Vaida.app.SpotFile/Data/Library/Application Support")
                        
                        try await MainActor.run {
                            try Task.checkCancellation()
                            self.matches = [(0, GoToItem(item: item, iconSystemName: "house"), QueryItem.Match(text: Text("goto: ") + Text(self.searchText).bold() + Text("NSHomeDirectory()".dropFirst(self.searchText.count)), isPrimary: true))]
                        }
                        
                        matchesIsUpdated = true
                    }
                    
                    if matchesIsUpdated {
                        logger.trace("assumed input of \"\(searchText)\" is file path.")
                    } else {
                        logger.trace("will exit without finding any match")
                    }
                }
                
                if !matchesIsUpdated {
                    try await MainActor.run {
                        try Task.checkCancellation()
                        self.matches = itemsMatches.enumerated().map { ($0.0, $0.1.0, $0.1.1) }
                    }
                }
                
                previous.matches = itemsMatches.map(\.0)
                previous.childrenMatches = []
                previous.parentQuery = nil
                try await onComplete()
            }
            
            guard itemsMatches.isEmpty && (previous.matches.count == 1 || previous.matches.contains(where: { searchText.lowercased().hasPrefix($0.query.content.lowercased())})) else {
                try await exitWithoutDeepSearch()
                return
            }
            try Task.checkCancellation()
            
            if previous.matches.count > 1 {
                previous.matches = [previous.matches.first(where: { searchText.lowercased().hasPrefix($0.query.content.lowercased()) })!]
            }
            
            guard (previous.matches.first?.childOptions.isEnabled ?? false) && (searchText.hasPrefix(" ") || searchText.hasSuffix(" ") || (previous.parentQuery != nil && searchText.hasPrefix(previous.parentQuery!))) else {
                try await exitWithoutDeepSearch()
                return
            }
            try Task.checkCancellation()
            
            var isInitial: Bool = false
            if previous.parentQuery == nil {
                isInitial = true
                previous.parentQuery = previous.searchText
            }
            let searchText = if isInitial {
                String(searchText.dropFirst(previous.searchText.count))
            } else {
                searchText
            }
            
            var _matches: [(any QueryItemProtocol, QueryItem.Match)]
            if !previous.childrenMatches.isEmpty && canUseLastResult {
                logger.trace("deep search: can use last result")
                _matches = try await previous.childrenMatches.stream.map { child in
                    try await self._recursiveMatch(child, childOptions: previous.matches.first!.childOptions, searchText: searchText, context: context)
                }.flatten().sequence
            } else {
                // cannot use last result
                logger.trace("deep search: cannot use last result, use search text: \(searchText)")
                _matches = try await self._recursiveMatch(previous.matches.first!, childOptions: previous.matches.first!.childOptions, searchText: searchText, context: context)
            }
            
            
            let search = String(searchText.dropFirst(while: { $0.isWhitespace }))
            if !search.isEmpty {
                let parentID = previous.matches.first!.id
                
                let models = try context.fetch(FetchDescriptor<QueryChildRecord>(predicate: #Predicate { $0.parentID == parentID })).filter({ search.starts(with: $0.query) })
                
                _matches = _matches.sorted(on: { match in
                    if match.0.query.content.lowercased() == searchText.lowercased() {
                        return Int.max
                    } else {
                        let _models = models.filter({ $0.relativePath == match.0.openableFileRelativePath })
                        let maxMatch = _models.map(\.count).max() ?? 0
                        return maxMatch << 32 | (Int(UInt32.max) - match.0.query.content.count)
                    }
                }, by: >)
            }
            
            previous.childrenMatches = _matches.map(\.0)
            
            let __matches = _matches.enumerated().map { ($0.0, $0.1.0, $0.1.1) }
            try await MainActor.run {
                try Task.checkCancellation()
                self.matches = __matches
            }
            try await onComplete()
        }
    }
    
    
    /// Explicitly make async to wait for fileI/O.
    private nonisolated static func checkFileType(item: FinderItem) async -> Bool {
        !((try? item.fileType.contains(.package)) ?? false)
    }
    private nonisolated static func checkIfFileIsIncluded(child: FinderItem, childOptions: QueryItem.ChildOptions) async -> Bool {
        (childOptions.includeFolder && child.isDirectory) || (childOptions.includeFile && child.isFile)
    }
    private nonisolated static func getChildStream(item: FinderItem) async throws -> some ConcurrentStream<FinderItem, Never> {
        try item.children(range: .contentsOfDirectory).stream
    }
    
    private nonisolated static func _check(item: some QueryItemProtocol, searchText: String, context: ModelContext) async throws -> QueryItem.Match? {
//        return item.match(query: searchText)
        
        let content = item.query.content
        var fetch = FetchDescriptor<UnmatchedSearch>(predicate: #Predicate { $0.query == content })
        fetch.fetchLimit = 1
        let unmatchedPrefix = try await MainActor.run {
            try context.fetch(fetch)
        }
        
        if let unmatch = unmatchedPrefix.first,
            unmatch.unmatchedPrefixes.prefixes.contains(where: { searchText.starts(with: $0) }) {
            return nil
        }
        
        if let match = item.match(query: searchText) {
            return match
        } else {
            Task { @MainActor in
                if let unmatch = unmatchedPrefix.first {
                    unmatch.unmatchedPrefixes.prefixes.append(content)
                } else {
                    context.insert(UnmatchedSearch(query: content, unmatchedPrefixes: UnmatchedSearch.UnmatchedPrefixes(prefixes: [searchText])))
                }
            }
            
            return nil
        }
    }
    
    private nonisolated func _recursiveMatch(
        _ item: any QueryItemProtocol,
        childOptions: QueryItem.ChildOptions,
        searchText: String,
        context: ModelContext
    ) async throws -> [(any QueryItemProtocol, QueryItem.Match)] {
        try Task.checkCancellation()
        
        // if `item` matches
        if !(item is QueryItem) {
            // the actual matching
            if childOptions.filterContains(item.item.name), let match = try await ModelProvider._check(item: item, searchText: searchText, context: context) {
                return [(item, match)]
            } else if !childOptions.enumeration {
                return [] // ends here
            }
        }
        
        guard await ModelProvider.checkFileType(item: item.item) else { return [] }
        
        return try await ModelProvider.getChildStream(item: item.item).map { (child) -> [(any QueryItemProtocol, QueryItem.Match)] in
            guard await ModelProvider.checkIfFileIsIncluded(child: child, childOptions: childOptions) else { return [] }
            let queryChild = QueryItemChild(parent: item, filename: child.name)
            return try await self._recursiveMatch(queryChild, childOptions: childOptions, searchText: searchText, context: context)
        }.flatten().sequence
    }
    
    
    func submitItem(context: ModelContext) {
        guard selectionIndex < self.matches.count else { return }
        self.matches[selectionIndex].1.open(query: self.searchText, context: context)
    }
    
    func revealItem(context: ModelContext) {
        guard selectionIndex < self.matches.count else { return }
        self.matches[selectionIndex].1.reveal(query: self.searchText, context: context)
    }
    
    
    final class PreviousState {
        
        var searchText: String = ""
        
        var matches: [QueryItem] = []
        
        var parentQuery: String? = nil
        
        var childrenMatches: [any QueryItemProtocol] = []
        
        var task: Task<Void, any Error>?
        
        func reset() {
            self.task?.cancel()
            self.searchText = ""
            self.matches = []
            self.childrenMatches = []
            self.task = nil
            self.parentQuery = nil
        }
        
        static var preview: PreviousState {
            let state = PreviousState()
            state.matches.append(QueryItem.preview)
            return state
        }
        
    }
    
    
    /// The main ``DataProvider`` to work with.
    ///
    /// This structure can be accessed across the app, and any mutations are observed in all views.
    @MainActor
    static var instance: ModelProvider = {
        print(ModelProvider.storageLocation)
        do {
            let decoder = PropertyListDecoder()
            let data = try Data(contentsOf: ModelProvider.storageLocation)
            
            do {
                return try decoder.decode(ModelProvider.self, from: data)
            } catch {
                print(error)
                Task { @MainActor in
                    AlertManager(error).present()
                }
                return ModelProvider()
            }
        } catch {
            return ModelProvider()
        }
    }()
    
    
    static var preview: ModelProvider {
        ModelProvider(items: [.preview], previous: .preview)
    }
    
    private init(items: [QueryItem] = [], previous: PreviousState = PreviousState()) {
        self.items = items
        self.previous = previous
    }
    
    enum CodingKeys: CodingKey {
        case _items
    }
    
}
