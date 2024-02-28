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
    
    var query: String {
        didSet {
            self.queryComponents = updateQueryComponents()
        }
    }
    
    var item: FinderItem {
        didSet {
            isItemUpdated = true
        }
    }
    
    @ObservationIgnored
    var isItemUpdated = false
    
    var openableFileRelativePath: String
    
    var icon: Icon
    
    var iconSystemName: String = ""
    
    
    var mustIncludeFirstKeyword = false
    
    @ObservationIgnored
    var openedRecords: [String: Int]
    
    
    /// the returned components are lowercased.
    @ObservationIgnored
    var queryComponents: [QueryComponent] = []
    
    @ObservationIgnored
    var children: [QueryItemChild] = []
    
    var childOptions: ChildOptions = .init()
    
    
    func updateIcon() async throws {
        let icon = try await self.item.preview(size: .square(64))
        self.icon.image = icon
    }
    
    func updateChildren() async throws {
        var children: [FinderItem] = []
        for await child in try item.children(range: childOptions.enumeration ? .enumeration : .contentsOfDirectory) {
            guard (childOptions.includeFolder && child.isDirectory) || (childOptions.includeFile && child.isFile) else { continue }
            children.append(child)
        }
        
        self.children = children.map { QueryItemChild(parent: self, openableFileRelativePath: $0.relativePath(to: item) ?? "", openedRecords: [:]) }
    }
    
    func delete() throws {
        try FinderItem(at: ModelProvider.storageLocation).enclosingFolder.appending(path: "icons").appending(path: "\(self.icon.id).heic").removeIfExists()
        try FinderItem(at: ModelProvider.storageLocation).enclosingFolder.appending(path: "bookmarks").appending(path: self.id.description).removeIfExists()
        
        self.isItemUpdated = true // set to true is case undo
        self.icon.isUpdated = true
    }
    
    
    static let separators: [Character] = ["_", "/"]
    
    
    
    init(query: String, item: FinderItem, openableFileRelativePath: String) {
        self.id = UUID()
        self.query = query
        self.item = item
        self.openableFileRelativePath = openableFileRelativePath
        self.icon = Icon(image: nil)
        self.openedRecords = [:]
        
        self.queryComponents = updateQueryComponents()
    }
    
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
        
    }
    
    
    // MARK: - Codable
    
    enum CodingKeys: CodingKey {
        case id
        case _query
        case _openableFileRelativePath
        case _icon
        case _iconSystemName
        case _openedCount
        case _mustIncludeFirstKeyword
        case _openedRecords
        case _children
        case _childOptions
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(self.id, forKey: .id)
        try container.encode(self._query, forKey: ._query)
        
        let bookmarkData = FinderItem(at: ModelProvider.storageLocation).enclosingFolder.appending(path: "bookmarks").appending(path: id.description)
        if isItemUpdated {
            try item.url.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil).write(to: bookmarkData)
            isItemUpdated = false
        }
        
        try container.encode(self._openableFileRelativePath, forKey: ._openableFileRelativePath)
        try container.encode(self._icon, forKey: ._icon)
        try container.encode(self._iconSystemName, forKey: ._iconSystemName)
        try container.encode(self.openedRecords, forKey: ._openedRecords)
        try container.encode(self._mustIncludeFirstKeyword, forKey: ._mustIncludeFirstKeyword)
        try container.encode(self.children, forKey: ._children)
        try container.encode(self._childOptions, forKey: ._childOptions)
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(UUID.self, forKey: .id)
        self._query = try container.decode(String.self, forKey: ._query)
        
        let bookmarkData = FinderItem(at: ModelProvider.storageLocation).enclosingFolder.appending(path: "bookmarks").appending(path: id.description)
        
        var bookmarkDataIsStale = false
        let url = try URL(resolvingBookmarkData: Data(at: bookmarkData), options: [], relativeTo: nil, bookmarkDataIsStale: &bookmarkDataIsStale)
        if bookmarkDataIsStale {
            try url.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil).write(to: bookmarkData)
        }
        
        self._item = FinderItem(at: url)
        
        self._openableFileRelativePath = try container.decode(String.self, forKey: ._openableFileRelativePath)
        self._icon = try container.decode(Icon.self, forKey: ._icon)
        self._iconSystemName = try container.decode(String.self, forKey: ._iconSystemName)
        self.openedRecords = try container.decode([String:Int].self, forKey: ._openedRecords)
        self._mustIncludeFirstKeyword = try container.decode(Bool.self, forKey: ._mustIncludeFirstKeyword)
        self.childOptions = try container.decode(ChildOptions.self, forKey: ._childOptions)
        self.queryComponents = updateQueryComponents()
        
        self.children = try container.decode([QueryItemChild].self, forKey: ._children)
        for index in 0..<self.children.count {
            self.children[index].parent = self
        }
    }
}
