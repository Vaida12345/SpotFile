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
    
    var searchText: String = "" {
        didSet {
            updateSearches()
        }
    }
    
    var selectionIndex: Int = 0
    
    var shownStartIndex: Int = 0
    
    var matches: [(Int, any QueryItemProtocol, QueryItem.Match)] = []
    
    var isSearching = false
    
    
    func updateSearches() {
        guard !searchText.isEmpty else {
            selectionIndex = 0
            matches.removeAll()
            previous.reset()
            return
        }
        
        let previous = previous // cross actor.
        
        isSearching = true
        let searchText = searchText
        let previousSearchText = previous.searchText
        self.selectionIndex = 0
        
        let canUseLastResult = searchText.hasPrefix(previousSearchText) && previous.task == nil
        previous.task?.cancel()
        
        previous.task = Task.detached {
            let date = Date()
            print("updateSearches(\(searchText)) enter @\(Date().timeIntervalSinceReferenceDate)")
            defer {
                print("updateSearches(\(searchText)) exit @\(Date().timeIntervalSinceReferenceDate)\n")
            }
            func onComplete() {
                print("updateSearches(\(searchText)) took: \(date.distanceToNow())")
                previous.searchText = searchText
                previous.task = nil
                
                Task { @MainActor in
                    self.isSearching = false
                }
            }
            
            if searchText.count < previousSearchText.count {
                // is deleting, then wait for a sec before conducting any search
                try await Task.sleep(for: .milliseconds(50))
            }
            try Task.checkCancellation()
            
            let total = !previousSearchText.isEmpty && canUseLastResult ? previous.matches : self.items
            
            let itemsMatches: [(QueryItem, QueryItem.Match)] = if previous.parentQuery != nil {
                []
            } else {
                try await total.stream.compactMap { item in
                    try Task.checkCancellation()
                    
                    if let string = item.match(query: self.searchText) {
                        return (item, string)
                    } else {
                        return nil
                    }
                }.sequence.sorted(on: {
                    ($0.0.openedRecords.filter({ $0.key.hasPrefix(searchText) }).map(\.value).max() ?? 0) << 32 | (Int(UInt32.max) - $0.0.query.content.count)
                }, by: >)
            }
            
            Task { @MainActor in
                self.matches = itemsMatches.enumerated().map { ($0.0, $0.1.0, $0.1.1) }
            }
            try Task.checkCancellation()
            
            var _matches: [(any QueryItemProtocol, QueryItem.Match)] = []
            
            guard itemsMatches.isEmpty && previous.matches.count == 1 else {
                previous.matches = itemsMatches.map(\.0)
                previous.childrenMatches = []
                previous.parentQuery = nil
                onComplete()
                return
            }
            
            var isInitial: Bool = false
            if previous.parentQuery == nil {
                isInitial = true
                previous.parentQuery = previous.searchText
            }
            let searchText = if isInitial {
                String(self.searchText.dropFirst(previous.searchText.count))
            } else {
                self.searchText
            }
            
            if !previous.childrenMatches.isEmpty && canUseLastResult {
                print("can use last result")
                _matches = try await withThrowingTaskGroup(of: [(any QueryItemProtocol, QueryItem.Match)].self) { group in
                    for child in previous.childrenMatches {
                        guard group.addTaskUnlessCancelled(operation: {
                            try await self._recursiveMatch(child, childOptions: previous.matches.first!.childOptions, searchText: searchText)
                        }) else { return [] }
                    }
                    
                    return try await group.allObjects().flatten()
                }
            } else {
                // cannot use last result
                print("cannot use last result, using search text \"\(searchText)\"")
                _matches = try await self._recursiveMatch(previous.matches.first!, childOptions: previous.matches.first!.childOptions, searchText: searchText)
            }
            
            previous.childrenMatches = _matches.map(\.0)
            
            let __matches = _matches.enumerated().map { ($0.0, $0.1.0, $0.1.1) }
            Task { @MainActor in
                self.matches = __matches
            }
            onComplete()
        }
    }
    
    private func _recursiveMatch(_ item: any QueryItemProtocol, childOptions: QueryItem.ChildOptions, searchText: String) async throws -> [(any QueryItemProtocol, QueryItem.Match)] {
        try Task.checkCancellation()
        // if `item` matches
        if let match = item.match(query: searchText) {
            if !searchText.allSatisfy({ $0.isWhitespace || QueryItem.separators.contains($0) }) {
                return [(item, match)]
            } else {
                return try await item.item.children(range: .contentsOfDirectory).compactMap { child in
                    guard (childOptions.includeFolder && child.isDirectory) || (childOptions.includeFile && child.isFile) else { return nil }
                    let queryChild = QueryItemChild(parent: item, filename: child.name)
                    return (queryChild, QueryItem.Match(text: Text(child.name), isPrimary: true))
                }.allObjects()
            }
        }
        
        try Task.checkCancellation()
        
        return try await withThrowingTaskGroup(of: [(any QueryItemProtocol, QueryItem.Match)].self) { group in
            for await child in try item.item.children(range: .contentsOfDirectory) {
                guard (childOptions.includeFolder && child.isDirectory) || (childOptions.includeFile && child.isFile) else { continue }
                guard group.addTaskUnlessCancelled(operation: {
                    let queryChild = QueryItemChild(parent: item, filename: child.name)
                    return try await self._recursiveMatch(queryChild, childOptions: childOptions, searchText: searchText)
                }) else { return [] }
            }
            
            return try await group.allObjects().flatten()
        }
    }
    
    
    func submitItem() {
        guard searchText != "NSHomeDirectory()" else {
            Task {
                try? await FinderItem.homeDirectory.open()
                postSubmitAction()
            }
            return
        }
        guard selectionIndex < self.matches.count else { return }
        self.matches[selectionIndex].1.open(query: self.searchText)
    }
    
    func revealItem() {
        guard selectionIndex < self.matches.count else { return }
        self.matches[selectionIndex].1.reveal(query: self.searchText)
    }
    
    
    final class PreviousState {
        
        var searchText: String = ""
        
        var matches: [QueryItem] = []
        
        var parentQuery: String? = nil
        
        var childrenMatches: [any QueryItemProtocol] = []
        
        var task: Task<Void, any Error>?
        
        func reset() {
            self.searchText = ""
            self.matches = []
            self.childrenMatches = []
            self.task?.cancel()
            self.task = nil
            self.parentQuery = nil
        }
        
    }
    
    
    /// The main ``DataProvider`` to work with.
    ///
    /// This structure can be accessed across the app, and any mutations are observed in all views.
    static var instance: ModelProvider = {
        print(ModelProvider.storageLocation)
        do {
            let decoder = PropertyListDecoder()
            let data = try Data(contentsOf: ModelProvider.storageLocation)
            return try! decoder.decode(ModelProvider.self, from: data)
        } catch {
            return ModelProvider()
        }
    }()
    
    
    static let preview = ModelProvider(items: [.preview])
    
    private init(items: [QueryItem] = []) {
        self.items = items
    }
    
    enum CodingKeys: CodingKey {
        case _items
    }
    
}
