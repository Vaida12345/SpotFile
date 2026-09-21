 //
//  FileSearcher.swift
//  SpotFile
//
//  Created by Vaida on 2026-09-21.
//

import Combine
import MacroCollection
import SwiftData
import OSLog
import FinderItem
import ConcurrentStream
import SwiftUI


final class FileSearcher {
    
    private var previousCompleteSearch: SearchState? = nil
    
    func reset() {
        self.previousCompleteSearch = nil
    }
    
    nonisolated static func gotoFilePath(request: SearchRequest) async -> SearchState? {
        guard request.parent == nil else { return nil }
        
        func set(goto: String) async -> SearchState? {
            let item = FinderItem(at: goto)
            guard item.exists else { return nil }
            
            return SearchState(
                request: request,
                match: .goto(
                    GoToItem(item: item, iconSystemName: ""),
                    QueryItem.Match(text: Text("goto: ") + Text(verbatim: item.name).bold(), isPrimary: true)
                ),
                options: []
            )
        }
        
        if request.text.starts(with: "/") {
            return await set(goto: request.text)
        } else if request.text.starts(with: "~") {
            return await set(goto: request.text.replacing(/^~/, with: NSHomeDirectory()))
        } else if request.text.hasPrefix("file:") {
            return await set(goto: "/" + request.text.dropFirst(5).dropFirst(while: { $0 == "/" }))
        } else if "NSHomeDirectory()".starts(with: request.text) {
            let item = FinderItem.homeDirectory.appending(path: "/Library/Containers/Vaida.app.SpotFile/Data/Library/Application Support")
            
            return SearchState(
                request: request,
                match: .goto(
                    GoToItem(item: item, iconSystemName: "house"),
                    QueryItem.Match(
                        text: Text("goto: ") + Text(verbatim: request.text).bold() + Text(verbatim: String("NSHomeDirectory()".dropFirst(request.text.count))),
                        isPrimary: true
                    )
                ),
                options: []
            )
        }
        
        return nil
    }
    
    // not private for testing.
    nonisolated static func performSearches(request: SearchRequest, previous: SearchState?, context: ModelContext, in items: [QueryItem]) async throws -> SearchState {
        guard !request.text.isEmpty else {
            return SearchState(request: request, match: nil, options: .reset)
        }
        
#if DEBUG
        let logger = Logger(subsystem: "app.Vaida.spotFile", category: "Search")
        logger.info("Search for '\(request.text)' in \(request.parent?.description ?? "<none>"); previous: \(String(reflecting: previous))")
#endif
        
        if let goto = await self.gotoFilePath(request: request) {
            return goto
        }
        
        let canUseLastResult = previous.isNoneNil(and: { !$0.request.text.isEmpty && request.text.hasPrefix($0.request.text) })
        
        // Pre-compute lowercased values once per search
        let lowercasedQueryChars = Array(request.text.precomposedStringWithCanonicalMapping.lowercased())
        let loweredSearchText = String(lowercasedQueryChars)
        
        
        do {
            // MARK: - direct search
            try Task.checkCancellation()
            
            let candidates: [QueryItem]
            if canUseLastResult, let previous = previous?.match?.as(.direct) {
                candidates = previous.map(\.0)
            } else {
                candidates = items
            }
            
#if DEBUG
            let __fetch_date = Date()
#endif
            
            let directMatches: [(QueryItem, QueryItem.Match)]
            if canUseLastResult, previous?.match?.is(.deep) == true {
                directMatches = []
            } else if request.parent != nil {
                directMatches = []
            } else {
                // Pre-compute openedRecords scores for sorting
                let recordScores: [UUID: Int] = items.reduce(into: [:]) { dict, item in
                    let maxCount = item.openedRecords
                        .filter { $0.key.hasPrefix(request.text) }
                        .map(\.value).max() ?? 0
                    if maxCount > 0 { dict[item.id] = maxCount }
                }
                
                directMatches = try await candidates.stream.compactMap { item in
                    if let string = try await _check(item: item, lowercasedQueryChars: lowercasedQueryChars) {
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
            
            // MARK: - check if deep search
            
            var deepSearchTarget: QueryItem? = nil
            /// The query that leads to the finding of the deep search target.
            var _targetQuery: String? = nil
            var deepSearchText: String = request.text
            
            var canUseLastResultDeep: Bool {
                if canUseLastResult { return true }
                
                guard let previous else { return false }
                guard !previous.request.text.isEmpty else { return false }
                
                switch previous.match {
                case .direct:
                    return false
                case .deep(let target, _, _):
                    if request.parent?.id == target.id {
                        return request.text.hasPrefix(previous.request.text) || previous.request.parent == nil // is first
                    } else {
                        return false
                    }
                default:
                    return false
                }
            }
            
            if let parent = request.parent {
                deepSearchTarget = parent
            } else if let previous, directMatches.isEmpty, canUseLastResultDeep { // only true AFTER exhausting the search AND previous indicates can deep search.
                switch previous.match {
                case let .deep(target, targetQuery, matches: _):
                    deepSearchTarget = target
                    deepSearchText = String(request.text.trimmingPrefix(targetQuery ?? ""))
                case .direct(let matches):
                    if matches.count == 1, let firstMatch = matches.first {
                        deepSearchTarget = firstMatch.0
                        
                        _targetQuery = previous.request.text
                        deepSearchText = String(request.text.trimmingPrefix(_targetQuery ?? ""))
                    }
                default:
                    break
                }
            } else if directMatches.isEmpty { // also possible of previous matches missed, leading to no result.
                var index = lowercasedQueryChars.startIndex
                while index < lowercasedQueryChars.endIndex {
                    let char = lowercasedQueryChars[index]
                    if char.isWhitespace || QueryItem.separators.contains(char) {
                        let candidate = Array(lowercasedQueryChars[..<index])
                        if let onlyMatch = candidates.onlyMatch(where: { $0.matches(lowercasedQueryChars: candidate) }) {
                            deepSearchTarget = onlyMatch
                            _targetQuery = String(candidate)
                            deepSearchText = String(lowercasedQueryChars[index...])
                            
                            break
                        }
                    }
                    index &+= 1
                }
            }
            
            guard let deepSearchTarget else {
#if DEBUG
                logger.trace("Exit as no deep search target")
#endif
                return SearchState(request: request, match: .direct(directMatches), options: [])
            }
            
            try Task.checkCancellation()
            
            var canPerformDeepSearchOnTarget: Bool {
                guard deepSearchTarget.childOptions.isEnabled else { return false }
                return deepSearchText.hasPrefix(" ") || deepSearchText.hasSuffix(" ")
            }
            
            guard canPerformDeepSearchOnTarget else {
#if DEBUG
                logger.trace("Exit as cannot perform deep search on \(deepSearchTarget)")
#endif
                return SearchState(request: request, match: .direct(directMatches), options: [])
            }
            
            // MARK: - deep search
            
            try Task.checkCancellation()
            
            let lowercasedDeepQueryChars = Array(deepSearchText.lowercased())
            let loweredDeepSearchText = String(lowercasedDeepQueryChars)
            
            let __fetch_children_date = Date()
            var deepMatches: [(any QueryItemProtocol, QueryItem.Match)]
            
            if let previous, canUseLastResultDeep, let previousMatches = previous.match?.as(.deep)?.matches {
#if DEBUG
                logger.trace("deep search: can use last result")
#endif
                let _deepSearchText = deepSearchText
                deepMatches = try await previousMatches.stream.map { child in
                    try await self._recursiveMatch(child.0, childOptions: deepSearchTarget.childOptions, searchText: _deepSearchText, lowercasedQueryChars: lowercasedDeepQueryChars)
                }.flatten().sequence
            } else {
                // cannot use last result
#if DEBUG
                logger.trace("deep search: cannot use last result, use search text: \(deepSearchText)")
#endif
                deepMatches = try await self._recursiveMatch(deepSearchTarget, childOptions: deepSearchTarget.childOptions, searchText: deepSearchText, lowercasedQueryChars: lowercasedDeepQueryChars)
            }
#if DEBUG
            let logger = Logger(subsystem: "app.Vaida.spotFile", category: "Deep Search '\(deepSearchText)'")
            logger.debug("fetch children in \(__fetch_children_date.distanceToNow())")
#endif
            
            
            let search = String(deepSearchText.dropFirst(while: { $0.isWhitespace }))
            if !search.isEmpty {
                let parentID = deepSearchTarget.id
                
                let models = try context.fetch(FetchDescriptor<QueryChildRecord>(predicate: #Predicate { $0.parentID == parentID })).filter({ search.starts(with: $0.query) })
                
                // Pre-compute model scores for sort
                let modelScores: [String: Int] = models.reduce(into: [:]) { dict, model in
                    dict[model.relativePath] = max(dict[model.relativePath] ?? 0, model.count)
                }
                
                deepMatches = deepMatches.sorted(on: { match in
                    if match.0.query.lowercasedContent == loweredDeepSearchText {
                        return Int.max
                    } else {
                        let maxMatch = modelScores[match.0.openableFileRelativePath] ?? 0
                        return maxMatch << 32 | (Int(UInt32.max) - match.0.query.content.count)
                    }
                }, by: >)
            }
            
            return SearchState(
                request: request,
                match: .deep(target: deepSearchTarget, targetQuery: _targetQuery, matches: deepMatches),
                options: []
            )
        } catch {
#if DEBUG
            logger.debug("Got error: \(error)")
#endif
            throw error
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
        try item.children(range: .contentsOfDirectory.noOrder).stream
    }
    
    private nonisolated static func _check(item: some QueryItemProtocol, lowercasedQueryChars: [Character]) async throws -> QueryItem.Match? {
        guard item.matches(lowercasedQueryChars: lowercasedQueryChars) else { return nil }
        return item.match(lowercasedQueryChars: lowercasedQueryChars)
    }
    
    private nonisolated static func _recursiveMatch(
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
                   let match = try await _check(item: item, lowercasedQueryChars: lowercasedQueryChars),
                   await checkIfFileIsIncluded(child: item.item, childOptions: childOptions) {
                    return [(item, match)]
                } else if !childOptions.enumeration {
                    return [] // ends here
                }
            }
            
            return []
        }
        
        let match = try await match()
        
        guard await checkFileType(item: item.item),
              item.item.isDirectory,
              (item is QueryItem) || childOptions.enumeration,
              match.isEmpty else { return match }
        
        return try await getChildStream(item: item.item).map { (child) -> [(any QueryItemProtocol, QueryItem.Match)] in
            let queryChild = QueryItemChild(parent: item, filename: child.name)
            return try await self._recursiveMatch(queryChild, childOptions: childOptions, searchText: searchText, lowercasedQueryChars: lowercasedQueryChars)
        }.flatten().sequence + match
    }
    
    
    
    // MARK: - Combine
    
    private let searchRequests = PassthroughSubject<SearchRequest, Never>()
    
    private let isSearchingSubject = CurrentValueSubject<Bool, Never>(false)
    
    var isSearching: some Publisher<Bool, Never> {
        isSearchingSubject
            .removeDuplicates()
            .eraseToAnyPublisher()
    }
    
    func createPublisher(context: ModelContext) -> AnyPublisher<SearchState, Never> {
        searchRequests
            .debounce(for: .milliseconds(50), scheduler: RunLoop.main)
            .removeDuplicates()
            .map {
                self.searchPublisher(request: $0, context: context)
            }
            .switchToLatest()
            .handleEvents(receiveOutput: { output in
                if output.options.contains(.reset), output.match?.is(.goto) == true {
                    self.previousCompleteSearch = nil
                } else {
                    self.previousCompleteSearch = output
                }
            })
            .eraseToAnyPublisher()
    }
    
    func sendSearchRequest(_ text: String, parent: QueryItem? = nil) {
        self.searchRequests.send(SearchRequest(text: text, parent: parent))
    }
    
    
    private func searchPublisher(request: SearchRequest, context: ModelContext) -> AnyPublisher<SearchState, Never> {
        var task: Task<Void, Never>? = nil
        
        return Deferred {
            Future { promise in
                task = Task {
                    do {
                        let result = try await FileSearcher.performSearches(request: request, previous: self.previousCompleteSearch, context: context, in: ModelProvider.instance.items)
                        promise(.success(result))
                    } catch {
                        // ignore
                    }
                }
            }
        }
        .handleEvents(
            receiveSubscription: { [isSearchingSubject] _ in
                isSearchingSubject.send(true)
            },
            receiveCompletion: { [isSearchingSubject] _ in
                isSearchingSubject.send(false)
            },
            receiveCancel: { [isSearchingSubject] in
                isSearchingSubject.send(false)
                task?.cancel()
            }
        )
        .eraseToAnyPublisher()
    }
    
    struct SearchState {
        let request: SearchRequest
        let match: Match?
        let options: Options
        
        @accessingAssociatedValues
        enum Match {
            case direct([(QueryItem, QueryItem.Match)])
            case goto(GoToItem, QueryItem.Match)
            /// - Parameter:
            ///   - target: the target to which deep search is performed
            ///   - targetQuery: the query, if any, that leads to the deep search target. Only available when the query contains the target query.
            case deep(target: QueryItem, targetQuery: String?, matches: [(any QueryItemProtocol, QueryItem.Match)])
        }
        
        struct Options: OptionSet, Sendable, BitwiseCopyable, Hashable {
            var rawValue: UInt
            
            static let reset = Options(rawValue: 1 << 0)
        }
    }
    
    struct SearchRequest: Equatable {
        /// The search text. The text does not contain the query, if any, that leads to the deep search target.
        let text: String
        /// The deep search target.
        let parent: QueryItem?
        
        public static func == (_ lhs: Self, _ rhs: Self) -> Bool {
            lhs.text == rhs.text &&
            lhs.parent?.id == rhs.parent?.id
        }
    }
    
}
