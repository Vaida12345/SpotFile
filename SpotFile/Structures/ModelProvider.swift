//
//  ModelProvider.swift
//  SpotFile
//
//  Created by Vaida on 2024/2/4.
//

import Foundation
import SwiftUI
import UniformTypeIdentifiers
import ConcurrentStream
import SwiftData
import OSLog
import ViewCollection
import UndoTracking
import FinderItem


@Observable
final class ModelProvider: Codable, DataProvider, UndoTracking {
    
    static var instance = ModelProvider.load()
    
    init() { }
    
    var items: [QueryItem] = [] {
        didSet {
            selectionIndex = 0
            shownStartIndex = 0
            matches.removeAll()
        }
    }
    
    @ObservationIgnored
    var previous = PreviousState()
    
    var searchText: String = ""
    
    var selectionIndex: Int = 0
    
    var shownStartIndex: Int = 0
    
    var matches: [(Int, any QueryItemProtocol, QueryItem.Match)] = [] {
        didSet {
            selectionIndex = 0
            shownStartIndex = 0
        }
    }
    
    
    func reset() {
        self.searchText.removeAll()
        self.selectionIndex = 0
        self.shownStartIndex = 0
        
        self.previous.reset()
        self.matches.removeAll()
    }
    
    func updateSearches(context: ModelContext, forceDeepSearch: QueryItem? = nil) {
        guard !searchText.isEmpty else { self.reset(); return }
        
        #if DEBUG
        let logger = Logger(subsystem: "app.Vaida.spotFile", category: #function)
        let _startDate = Date()
        logger.trace("start to search for \"\(self.searchText)\"")
        #endif
        
        nonisolated(unsafe)
        let previous = previous
        let searchText = searchText
        let previousSearchText = previous.searchText
        nonisolated(unsafe)
        let context = context
        nonisolated(unsafe)
        let items = items
        nonisolated(unsafe)
        let matches = matches
        
        self.selectionIndex = 0
        
        let canUseLastResult = searchText.hasPrefix(previousSearchText) && previous.task == nil
        previous.task?.cancel()
        
        // Pre-compute lowercased values once per search
        let lowercasedQueryChars = Array(searchText.lowercased())
        let loweredSearchText = String(lowercasedQueryChars)
        
        previous.task = Task.detached {
            @MainActor
            func onComplete(matches: [QueryItem], childrenMatches: [any QueryItemProtocol], parentQuery: String?) throws {
                try Task.checkCancellation()
                
                previous.searchText = searchText
                previous.task = nil
                previous.childrenMatches = childrenMatches
                previous.parentQuery = parentQuery
                previous.matches = matches
                
                #if DEBUG
                logger.trace("searching \"\(searchText)\" completed within \(_startDate.distanceToNow())")
                #endif
            }
            
            if searchText.count < previousSearchText.count {
                // is deleting, then wait for a sec before conducting any search
                try await Task.sleep(for: .milliseconds(50))
            }
            try Task.checkCancellation()
            
            let total = !previousSearchText.isEmpty && canUseLastResult ? previous.matches : items
            
            // Pre-compute openedRecords scores for sorting
            let recordScores: [UUID: Int] = items.reduce(into: [:]) { dict, item in
                let maxCount = item.openedRecords
                    .filter { $0.key.hasPrefix(searchText) }
                    .map(\.value).max() ?? 0
                if maxCount > 0 { dict[item.id] = maxCount }
            }
            
            let __fetch_date = Date()
            
            let itemsMatches: [(QueryItem, QueryItem.Match)] = if previous.parentQuery != nil {
                []
            } else {
                try await total.stream.compactMap { item in
                    if let string = try await ModelProvider._check(item: item, lowercasedQueryChars: lowercasedQueryChars) {
                        return (item, string)
                    } else {
                        return nil
                    }
                }.sequence.sorted(on: {
                    if $0.0.query.lowercasedContent == loweredSearchText {
                        return Int.max
                    } else {
                        let recordScore = recordScores[$0.0.id] ?? 0
                        return recordScore << 32 | (Int(UInt32.max) - $0.0.query.content.count)
                    }
                }, by: >)
            }
            
#if DEBUG
            print("Fetch changes in", __fetch_date.distanceToNow())
            #endif
            
            func exitWithoutDeepSearch() async throws {
#if DEBUG
                logger.trace("not perform deep search for \"\(searchText)\", exit with current match count: \(itemsMatches.count), previous match count: \(previous.matches.count)")
                #endif
                
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
                    
#if DEBUG
                    if matchesIsUpdated {
                        logger.trace("assumed input of \"\(searchText)\" is file path.")
                    } else {
                        logger.trace("will exit without finding any match")
                    }
#endif
                }
                
                if !matchesIsUpdated {
                    let _matches = itemsMatches.enumerated().map { ($0.0, $0.1.0, $0.1.1) }
                    let date = Date()
                    
                    if _matches.map(\.2) != matches.map(\.2) {
                        let __prepare_main_thread_date = Date()
                        try await MainActor.run {
                            print("prepare main thread in", __prepare_main_thread_date.distanceToNow())
                            
                            try Task.checkCancellation()
                            self.matches = _matches
                        }
                    }
                    
#if DEBUG
                    print("push changes to main actor in", date.distanceToNow())
#endif
                }
                
                try await MainActor.run {
                    try onComplete(matches: itemsMatches.map(\.0), childrenMatches: [], parentQuery: nil)
                }
            }
            
            guard (itemsMatches.isEmpty && (previous.matches.count == 1 || previous.matches.contains(where: { loweredSearchText.hasPrefix($0.query.lowercasedContent) }))) || forceDeepSearch != nil else {
                try await exitWithoutDeepSearch()
                return
            }
            try Task.checkCancellation()
            
            if let forceDeepSearch {
                previous.matches = [forceDeepSearch]
            } else if previous.matches.count > 1 {
                previous.matches = [previous.matches.first(where: { loweredSearchText.hasPrefix($0.query.lowercasedContent) })!]
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
            let deepSearchText = if isInitial {
                String(searchText.dropFirst(previous.searchText.count))
            } else {
                searchText
            }
            let lowercasedDeepQueryChars = Array(deepSearchText.lowercased())
            let loweredDeepSearchText = String(lowercasedDeepQueryChars)
            
            let __fetch_children_date = Date()
            var _matches: [(any QueryItemProtocol, QueryItem.Match)]
            if !previous.childrenMatches.isEmpty && canUseLastResult {
                #if DEBUG
                logger.trace("deep search: can use last result")
                #endif
                _matches = try await previous.childrenMatches.stream.map { child in
                    try await self._recursiveMatch(child, childOptions: previous.matches.first!.childOptions, searchText: deepSearchText, lowercasedQueryChars: lowercasedDeepQueryChars)
                }.flatten().sequence
            } else {
                // cannot use last result
#if DEBUG
                logger.trace("deep search: cannot use last result, use search text: \(deepSearchText)")
#endif
                _matches = try await self._recursiveMatch(previous.matches.first!, childOptions: previous.matches.first!.childOptions, searchText: deepSearchText, lowercasedQueryChars: lowercasedDeepQueryChars)
            }
#if DEBUG
            print("fetch children in ", __fetch_children_date.distanceToNow())
#endif
            
            
            let search = String(deepSearchText.dropFirst(while: { $0.isWhitespace }))
            if !search.isEmpty {
                let parentID = previous.matches.first!.id
                
                let models = try context.fetch(FetchDescriptor<QueryChildRecord>(predicate: #Predicate { $0.parentID == parentID })).filter({ search.starts(with: $0.query) })
                
                // Pre-compute model scores for sort
                let modelScores: [String: Int] = models.reduce(into: [:]) { dict, model in
                    dict[model.relativePath] = max(dict[model.relativePath] ?? 0, model.count)
                }
                
                _matches = _matches.sorted(on: { match in
                    if match.0.query.lowercasedContent == loweredDeepSearchText {
                        return Int.max
                    } else {
                        let maxMatch = modelScores[match.0.openableFileRelativePath] ?? 0
                        return maxMatch << 32 | (Int(UInt32.max) - match.0.query.content.count)
                    }
                }, by: >)
            }
            
            let __matches = _matches.enumerated().map { ($0.0, $0.1.0, $0.1.1) }
            try await MainActor.run {
                try Task.checkCancellation()
                self.matches = __matches
                try onComplete(matches: previous.matches, childrenMatches: _matches.map(\.0), parentQuery: previous.parentQuery)
            }
        }
    }
    
    
    /// Explicitly make async to wait for fileI/O.
    private nonisolated static func checkFileType(item: FinderItem) async -> Bool {
        !((try? item.url.resourceValues(forKeys: [.isPackageKey]).isPackage) ?? false)
    }
    private nonisolated static func checkIfFileIsIncluded(child: FinderItem, childOptions: QueryItem.ChildOptions) async -> Bool {
        (childOptions.includeFolder && child.isDirectory) || (childOptions.includeFile && child.isFile)
    }
    private nonisolated static func getChildStream(item: FinderItem) async throws -> some ConcurrentStream<FinderItem, Never> {
        try item.children(range: .contentsOfDirectory).stream
    }
    
    private nonisolated static func _check(item: some QueryItemProtocol, lowercasedQueryChars: [Character]) async throws -> QueryItem.Match? {
        guard item.matches(lowercasedQueryChars: lowercasedQueryChars) else { return nil }
        return item.match(lowercasedQueryChars: lowercasedQueryChars)
    }
    
    private nonisolated func _recursiveMatch(
        _ item: any QueryItemProtocol,
        childOptions: QueryItem.ChildOptions,
        searchText: String,
        lowercasedQueryChars: [Character]
    ) async throws -> [(any QueryItemProtocol, QueryItem.Match)] {
        try Task.checkCancellation()
        
        // if `item` matches
        func match() async throws -> [(any QueryItemProtocol, QueryItem.Match)] {
            if !(item is QueryItem) {
                // the actual matching
                if childOptions.filterContains(item.item.name),
                   let match = try await ModelProvider._check(item: item, lowercasedQueryChars: lowercasedQueryChars),
                   await ModelProvider.checkIfFileIsIncluded(child: item.item, childOptions: childOptions) {
                    return [(item, match)]
                } else if !childOptions.enumeration {
                    return [] // ends here
                }
            }
            
            return []
        }
        
        let match = try await match()
        
        guard await ModelProvider.checkFileType(item: item.item),
              item.item.isDirectory,
              (item is QueryItem) || childOptions.enumeration,
              match.isEmpty else { return match }
        
        return try await ModelProvider.getChildStream(item: item.item).map { (child) -> [(any QueryItemProtocol, QueryItem.Match)] in
            let queryChild = QueryItemChild(parent: item, filename: child.name)
            return try await self._recursiveMatch(queryChild, childOptions: childOptions, searchText: searchText, lowercasedQueryChars: lowercasedQueryChars)
        }.flatten().sequence + match
    }
    
    
    func submitItem(context: ModelContext) async {
        guard selectionIndex < self.matches.count else { return }
        await self.matches[selectionIndex].1.open(query: self.searchText, context: context)
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
            self.task = nil
            self.searchText = ""
            self.matches = []
            self.childrenMatches = []
            self.parentQuery = nil
        }
        
        static var preview: PreviousState {
            let state = PreviousState()
            state.matches.append(QueryItem.preview)
            return state
        }
        
    }
    
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
