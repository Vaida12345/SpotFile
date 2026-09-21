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
import Combine
import MacroCollection


@MainActor
@Observable
final class ModelProvider: @MainActor Codable, @MainActor DataProvider, UndoTracking {
    
    static var instance = ModelProvider.load()
    
    init() { }
    
    var items: [QueryItem] = [] {
        didSet {
            selectionIndex = 0
            shownStartIndex = 0
            matches.removeAll()
        }
    }
    
    var searchText: String = ""
    var isSearching: Bool = false
    
    var selectionIndex: Int = 0
    var shownStartIndex: Int = 0
    
    var deepSearchTarget: QueryItem?
    var matches: [(Int, any QueryItemProtocol, QueryItem.Match)] = [] {
        didSet {
            selectionIndex = 0
            shownStartIndex = 0
        }
    }
    
    func submitItem(context: ModelContext) async {
        guard selectionIndex < self.matches.count else { return }
        await self.matches[selectionIndex].1.open(query: self.searchText, context: context)
    }
    
    func revealItem(context: ModelContext) {
        guard selectionIndex < self.matches.count else { return }
        self.matches[selectionIndex].1.reveal(query: self.searchText, context: context)
    }
    
    static var preview: ModelProvider {
        ModelProvider(items: [.preview])
    }
    
    private init(items: [QueryItem] = []) {
        self.items = items
    }
    
    enum CodingKeys: CodingKey {
        case _items
    }
    
    
    func reset() {
        self.searchText.removeAll()
        self.selectionIndex = 0
        self.shownStartIndex = 0
        
        self.deepSearchTarget = nil
        self.matches.removeAll()
    }
    
}
