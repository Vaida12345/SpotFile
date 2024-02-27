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
    private var previousSearchText: String = ""
    
    var searchText: String = "" {
        didSet {
            let date = Date()
            
            guard !searchText.isEmpty else {
                selectionIndex = 0
                matches.removeAll()
                previousSearchText = ""
                return
            }
            
            let searchText = searchText
            let previousSearchText = previousSearchText
            Task { @MainActor in
                isSearching = true
                selectionIndex = 0
                
                Task.detached {
                    var matches: [(QueryItem, AttributedString)] = []
                    let total = !previousSearchText.isEmpty && searchText.hasPrefix(previousSearchText) ? self.matches.map(\.1) : self.items
                    
                    for item in total {
                        if let string = item.match(query: self.searchText) {
                            matches.append((item, string))
                        }
                    }
                    let _matches = matches.sorted(on: {
                        $0.0.openedRecords.filter({ $0.key.hasPrefix(searchText) }).map(\.value).max() ?? 0
                    }, by: >).enumerated().map { ($0.0, $0.1.0, $0.1.1) }
                    
                    Task { @MainActor in
                        print("conducting search took \(date.distanceToNow())")
                        self.matches = _matches
                        self.isSearching = false
                        self.previousSearchText = searchText
                    }
                }
            }
        }
    }
    
    var selectionIndex: Int = 0 
    
    var isSearching = false
    
    var matches: [(Int, QueryItem, AttributedString)] = []
    
    
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
