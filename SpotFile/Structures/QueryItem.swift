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
    
    var item: FinderItem
    
    var openableFileRelativePath: String
    
    /// If empty, use finder preview.
    var iconSystemName: String = ""
    
    
    @ObservationIgnored
    var openedRecords: [String: Int] = [:]
    
    var childOptions: ChildOptions = .init()
    
    var additionalQueries: [Query] = []
    
    func updateRecords(_ query: String) {
        self.openedRecords[query, default: 0] += 1
    }
    
    
    // MARK: - Handling matches
    
    func match(query: String) -> Match? {
        if let match = self.query.match(query: query, isChild: false) {
            return Match(text: match, isPrimary: true)
        }
        
        for additionalQuery in additionalQueries {
            if let match = additionalQuery.match(query: query, isChild: true) {
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
    
    static let separators: [Character] = ["_", "/"]
    
    static let preview = QueryItem(query: "swift testRoom",
                                   item: FinderItem(at: "/Users/vaida/Library/Mobile Documents/com~apple~CloudDocs/DataBase/Swift/testRoom/testRoom"),
                                   openableFileRelativePath: "testRoom.xcodeproj")
    
    static func new() -> QueryItem {
        QueryItem(query: "new", item: .homeDirectory, openableFileRelativePath: "")
    }
    
    
    // MARK: - Codable
    
    enum CodingKeys: CodingKey {
        case _query
        case _openableFileRelativePath
        case _iconSystemName
        case _openedRecords
        case _childOptions
        case _additionalQueries
        case _item
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(self._query, forKey: ._query)
        try container.encode(self._item, forKey: ._item)
        try container.encode(self._openableFileRelativePath, forKey: ._openableFileRelativePath)
        try container.encode(self._iconSystemName, forKey: ._iconSystemName)
        try container.encode(self.openedRecords, forKey: ._openedRecords)
        try container.encode(self._childOptions, forKey: ._childOptions)
        try container.encode(self._additionalQueries, forKey: ._additionalQueries)
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = UUID()
        self._query = try container.decode(Query.self, forKey: ._query)
        self._item = try container.decode(FinderItem.self, forKey: ._item)
        self._openableFileRelativePath = try container.decode(String.self, forKey: ._openableFileRelativePath)
        self._iconSystemName = try container.decode(String.self, forKey: ._iconSystemName)
        self.openedRecords = try container.decode([String:Int].self, forKey: ._openedRecords)
        self._childOptions = try container.decode(ChildOptions.self, forKey: ._childOptions)
        self._additionalQueries = try container.decode([Query].self, forKey: ._additionalQueries)
    }
}
