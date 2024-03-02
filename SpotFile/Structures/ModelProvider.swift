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
    private var previous = PreviousState()
    
    var searchText: String = "" {
        didSet {
            updateSearches()
        }
    }
    
    var selectionIndex: Int = 0
    
    var matches: [(Int, any QueryItemProtocol, Text)] = []
    
    var isSearching = false
    
    
    func updateSearches() {
        guard !searchText.isEmpty else {
            selectionIndex = 0
            matches.removeAll()
            previous.reset()
            return
        }
        
        isSearching = true
        let searchText = searchText
        let previousSearchText = previous.searchText
        Task { @MainActor in
            selectionIndex = 0
            previous.task?.cancel()
            
            previous.task = Task.detached {
                let date = Date()
                let canUseLastResult = searchText.hasPrefix(previousSearchText)
                if searchText.count < previousSearchText.count {
                    // is deleting, then wait for a sec before conducting any search
                    try await Task.sleep(for: .milliseconds(50))
                }
                try Task.checkCancellation()
                
                let total = !previousSearchText.isEmpty && canUseLastResult ? self.previous.matches : self.items
                
                var matches: [(any QueryItemProtocol, Text)] = if canUseLastResult && !self.previous.childrenMatches.isEmpty {
                    []
                } else {
                    try total.compactMap { item in
                        try Task.checkCancellation()
                        
                        if let string = item.match(query: self.searchText) {
                            return (item, string)
                        } else {
                            return nil
                        }
                    }
                }
                try Task.checkCancellation()
                
                if matches.isEmpty && self.previous.matches.count == 1 {
                    if !self.previous.childrenMatches.isEmpty && canUseLastResult {
                        matches = try self.previous.childrenMatches.compactMap { item in
                            try Task.checkCancellation()
                            
                            if let string = item.match(query: self.searchText) {
                                return (item, string)
                            } else {
                                return nil
                            }
                        }
                    } else {
                        let total = self.previous.matches.first!.children
                        var matchedPrefix = ""
                        
                        for item in total {
                            try Task.checkCancellation()
                            
                            if !matchedPrefix.isEmpty && item.query.hasPrefix(matchedPrefix) {
                                continue // must be in its subfolder, ignore
                            } else if let string = item.match(query: self.searchText) {
                                matches.append((item, string))
                                matchedPrefix = item.query
                            }
                        }
                    }
                    
                    self.previous.childrenMatches = matches.map { $0.0 as! QueryItemChild }
                } else {
                    self.previous.matches = matches.map { $0.0 as! QueryItem }
                    self.previous.childrenMatches = []
                }
                
                let _matches = matches.sorted(on: {
                    ($0.0.openedRecords.filter({ $0.key.hasPrefix(searchText) }).map(\.value).max() ?? 0) << 32 | (Int(UInt32.max) - $0.0.query.count)
                }, by: >).enumerated().map { ($0.0, $0.1.0, $0.1.1) }
                
                try Task.checkCancellation()
                
                print("conducting search took \(date.distanceToNow())")
                Task { @MainActor in
                    self.matches = _matches
                    self.previous.searchText = searchText
                    self.previous.task = nil
                    self.isSearching = false
                }
            }
        }
    }
    
    
    func submitItem() {
        guard searchText != "NSHomeDirectory()" else {
            try? FinderItem.homeDirectory.reveal()
            return
        }
        guard selectionIndex < self.matches.count else { return }
        self.matches[selectionIndex].1.open(query: self.searchText)
    }
    
    func revealItem() {
        guard selectionIndex < self.matches.count else { return }
        self.matches[selectionIndex].1.reveal(query: self.searchText)
    }
    
    
    struct PreviousState {
        
        var searchText: String = ""
        
        var matches: [QueryItem] = []
        
        var childrenMatches: [QueryItemChild] = []
        
        var task: Task<Void, any Error>?
        
        mutating func reset() {
            self.searchText = ""
            self.matches = []
            self.childrenMatches = []
            self.task = nil
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
            return try decoder.decode(ModelProvider.self, from: data)
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
