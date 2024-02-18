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
final class ModelProvider: Codable, DataProvider, ReferenceFileDocument {
    static var readableContentTypes: [UTType] = []
    
    func snapshot(contentType: UTType) throws -> ModelProvider {
        self
    }
    
    func fileWrapper(snapshot: ModelProvider, configuration: WriteConfiguration) throws -> FileWrapper {
        fatalError()
    }
    
    init(configuration: ReadConfiguration) throws {
        fatalError()
    }
    
    typealias Snapshot = ModelProvider
    
    
    var items: [QueryItem] = [] {
        didSet {
            selectionIndex = 0
            matches.removeAll()
        }
    }
    
    var searchText: String = "" {
        didSet {
            guard !searchText.isEmpty else {
                selectionIndex = 0
                matches.removeAll()
                return
            }
            
            Task { @MainActor in
                isSearching = true
                selectionIndex = 0
                
                Task.detached {
                    var matches: [(Int, QueryItem, AttributedString)] = []
                    for item in self.items {
                        if let string = item.match(query: self.searchText) {
                            matches.append((matches.count, item, string))
                        }
                    }
                    let _matches = consume matches
                    
                    Task { @MainActor in
                        self.matches = _matches
                        self.isSearching = false
                    }
                }
            }
        }
    }
    
    var selectionIndex: Int = 0 
    
    var isSearching = false
    
    var matches: [(Int, QueryItem, AttributedString)] = []
    
    
    func submitItem() {
        guard selectionIndex < self.matches.count else { return }
        self.matches[selectionIndex].1.open()
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
