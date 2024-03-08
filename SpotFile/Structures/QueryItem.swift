//
//  QueryItem.swift
//  SpotFile
//
//  Created by Vaida on 2024/2/4.
//

import Foundation
import Stratum
import SwiftUI


@Observable
final class QueryItem: Codable, Identifiable, QueryItemProtocol {
    
    let id: UUID
    
    var query: Query
    
    var item: FinderItem {
        willSet {
            item.url.stopAccessingSecurityScopedResource()
        }
        didSet {
            isItemUpdated = true
            let _ = item.url.startAccessingSecurityScopedResource()
        }
    }
    
    @ObservationIgnored
    var isItemUpdated = true
    
    var openableFileRelativePath: String
    
    /// If empty, use finder preview.
    var iconSystemName: String = ""
    
    
    @ObservationIgnored
    var openedRecords: [String: Int] = [:]
    
    var childOptions: ChildOptions = .init()
    
    var additionalQueries: [Query] = []
    
    
    func delete() throws {
        try FinderItem(at: ModelProvider.storageLocation).enclosingFolder.appending(path: "bookmarks").appending(path: self.id.description).removeIfExists()
        
        self.isItemUpdated = true // set to true is case undo
    }
    
    func updateRecords(_ query: String) {
        self.openedRecords[query, default: 0] += 1
    }
    
    
    // MARK: - Handling matches
    
    func match(query: String) -> Match? {
        if let match = self.query.match(query: query) {
            return Match(text: match, isPrimary: true)
        }
        
        for additionalQuery in additionalQueries {
            if let match = additionalQuery.match(query: query) {
                return Match(text: match, isPrimary: false)
            }
        }
        
        return nil
    }
    
    
    struct Match {
        
        let text: Text
        
        let isPrimary: Bool
        
    }
    
    
    // MARK: - Initializers, static values
    
    init(query: String, item: FinderItem, openableFileRelativePath: String) {
        self.id = UUID()
        self.query = Query(value: query)
        self.item = item
        self.openableFileRelativePath = openableFileRelativePath
    }
    
    deinit {
        self.item.url.stopAccessingSecurityScopedResource()
    }
    
    static let separators: [Character] = ["_", "/"]
    
    static let preview = QueryItem(query: "swift testRoom",
                                   item: FinderItem(at: "/Users/vaida/Library/Mobile Documents/com~apple~CloudDocs/DataBase/Swift/testRoom/testRoom"),
                                   openableFileRelativePath: "testRoom.xcodeproj")
    
    static func new() -> QueryItem {
        QueryItem(query: "new", item: .homeDirectory, openableFileRelativePath: "")
    }
    
    struct ChildOptions: Codable {
        
        /// Whether this item is a directory, and not a package.
        var isDirectory: Bool = false
        
        var isEnabled: Bool = false
        
        var includeFolder: Bool = true
        
        var includeFile: Bool = false
        
        var enumeration: Bool = true
        
        var filterBy: String = ""
        
        var filters: [Regex<Substring>] = []
        
        
        mutating func updateFilters() throws {
            var cumulative = ""
            var opened = false
            for c in filterBy {
                if c == "/" {
                    if opened {
                        try filters.append(Regex(cumulative))
                        cumulative = ""
                    }
                    opened.toggle()
                } else if !opened {
                    continue
                } else {
                    cumulative.append(c)
                }
            }
        }
        
        func filterContains(_ string: String) -> Bool {
            guard !filters.isEmpty else { return true }
            for filter in filters {
                if string.wholeMatch(of: filter) != nil { return true }
            }
            return false
        }
        
        
        internal init(isDirectory: Bool = false, 
                      isEnabled: Bool = false,
                      includeFolder: Bool = true,
                      includeFile: Bool = false,
                      enumeration: Bool = true,
                      filterBy: String = "") {
            self.isDirectory = isDirectory
            self.isEnabled = isEnabled
            self.includeFolder = includeFolder
            self.includeFile = includeFile
            self.enumeration = enumeration
            self.filterBy = filterBy
        }
        
        enum CodingKeys: CodingKey {
            case isDirectory
            case isEnabled
            case includeFolder
            case includeFile
            case enumeration
            case filterBy
        }
        
        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: QueryItem.ChildOptions.CodingKeys.self)
            try container.encode(self.isDirectory, forKey: QueryItem.ChildOptions.CodingKeys.isDirectory)
            try container.encode(self.isEnabled, forKey: QueryItem.ChildOptions.CodingKeys.isEnabled)
            try container.encode(self.includeFolder, forKey: QueryItem.ChildOptions.CodingKeys.includeFolder)
            try container.encode(self.includeFile, forKey: QueryItem.ChildOptions.CodingKeys.includeFile)
            try container.encode(self.enumeration, forKey: QueryItem.ChildOptions.CodingKeys.enumeration)
            try container.encode(self.filterBy, forKey: QueryItem.ChildOptions.CodingKeys.filterBy)
        }
        
        init(from decoder: Decoder) throws {
            let container: KeyedDecodingContainer<QueryItem.ChildOptions.CodingKeys> = try decoder.container(keyedBy: QueryItem.ChildOptions.CodingKeys.self)
            self.isDirectory = try container.decode(Bool.self, forKey: QueryItem.ChildOptions.CodingKeys.isDirectory)
            self.isEnabled = try container.decode(Bool.self, forKey: QueryItem.ChildOptions.CodingKeys.isEnabled)
            self.includeFolder = try container.decode(Bool.self, forKey: QueryItem.ChildOptions.CodingKeys.includeFolder)
            self.includeFile = try container.decode(Bool.self, forKey: QueryItem.ChildOptions.CodingKeys.includeFile)
            self.enumeration = try container.decode(Bool.self, forKey: QueryItem.ChildOptions.CodingKeys.enumeration)
            self.filterBy = try container.decodeIfPresent(String.self, forKey: QueryItem.ChildOptions.CodingKeys.filterBy) ?? ""
            
            try self.updateFilters()
        }
        
    }
    
    
    // MARK: - Codable
    
    enum CodingKeys: CodingKey {
        case id
        case _query
        case _openableFileRelativePath
        case _iconSystemName
        case _openedRecords
        case _childOptions
        case _additionalQueries
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(self.id, forKey: .id)
        try container.encode(self._query, forKey: ._query)
        
        let bookmarkData = FinderItem(at: ModelProvider.storageLocation).enclosingFolder.appending(path: "bookmarks").appending(path: id.description)
        if isItemUpdated {
            try bookmarkData.removeIfExists()
            try item.url.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil).write(to: bookmarkData)
            isItemUpdated = false
        }
        
        try container.encode(self._openableFileRelativePath, forKey: ._openableFileRelativePath)
        try container.encode(self._iconSystemName, forKey: ._iconSystemName)
        try container.encode(self.openedRecords, forKey: ._openedRecords)
        try container.encode(self._childOptions, forKey: ._childOptions)
        try container.encode(self._additionalQueries, forKey: ._additionalQueries)
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(UUID.self, forKey: .id)
        self._query = try container.decode(Query.self, forKey: ._query)
        
        let bookmarkData = FinderItem(at: ModelProvider.storageLocation).enclosingFolder.appending(path: "bookmarks").appending(path: id.description)
        
        var bookmarkDataIsStale = false
        let url = try URL(resolvingBookmarkData: Data(at: bookmarkData), options: [], relativeTo: nil, bookmarkDataIsStale: &bookmarkDataIsStale)
        if bookmarkDataIsStale {
            try bookmarkData.removeIfExists()
            try url.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil).write(to: bookmarkData)
        }
        let _ = url.startAccessingSecurityScopedResource()
        
        self._item = FinderItem(at: url)
        
        self._openableFileRelativePath = try container.decode(String.self, forKey: ._openableFileRelativePath)
        self._iconSystemName = try container.decode(String.self, forKey: ._iconSystemName)
        self.openedRecords = try container.decode([String:Int].self, forKey: ._openedRecords)
        self._childOptions = try container.decode(ChildOptions.self, forKey: ._childOptions)
        self._additionalQueries = try container.decode([Query].self, forKey: ._additionalQueries)
    }
}
