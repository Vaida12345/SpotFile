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
final class QueryItem: Codable, Identifiable {
    
    let id: UUID
    
    var query: String {
        didSet {
            updateQueryComponents()
        }
    }
    
    var item: FinderItem {
        didSet {
            isItemUpdated = true
        }
    }
    
    var isItemUpdated = false
    
    var openableFileRelativePath: String
    
    var icon: Icon
    
    var iconSystemName: String = ""
    
    
    var mustIncludeFirstKeyword = false
    
    var openedRecords: [String: Int]
    
    
    /// the returned components are lowercased.
    var queryComponents: [QueryComponent] = []
    
    @ViewBuilder
    var smallIconView: some View {
        if !self.iconSystemName.isEmpty {
            if self.iconSystemName == "xcodeproj" {
                Image(.xcodeproj)
            } else {
                Image(systemName: self.iconSystemName)
            }
        } else if let image = self.icon.image {
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
        } else {
            Image(systemName: "folder.badge.plus")
        }
    }
    
    var iconView: Image {
        if !self.iconSystemName.isEmpty {
            if self.iconSystemName == "xcodeproj" {
                Image(.xcodeproj)
            } else {
                Image(systemName: self.iconSystemName)
            }
        } else if let image = self.icon.image {
            Image(nsImage: image)
        } else {
            Image(systemName: "folder.badge.plus")
        }
    }
    
    private func updateQueryComponents() {
        var components: [QueryComponent] = []
        
        var index = self.query.startIndex
        var cumulative = ""
        
        while index < self.query.endIndex {
            if (self.query[index].isUppercase && !cumulative.isEmpty && !cumulative.allSatisfy(\.isUppercase)) {
                components.append(.content(cumulative))
                cumulative = ""
                continue
            } else if self.query[index].isWhitespace || self.query[index] == "_" {
                components.append(.content(cumulative))
                components.append(.spacer("\(self.query[index])"))
                cumulative = ""
                self.query.formIndex(after: &index)
                continue
            }
            
            cumulative.append(self.query[index])
            self.query.formIndex(after: &index)
        }
        
        if !cumulative.isEmpty {
            components.append(.content(cumulative))
        }
        
        queryComponents = components
    }
    
    func updateIcon() async throws {
        let icon = try await self.item.preview(size: .square(64))
        self.icon.image = icon
    }
    
    func reveal(query: String) {
        self.openedRecords[query, default: 0] += 1
        withErrorPresented {
            let path = self.item
            try path.reveal()
            
            Task.detached {
                try ModelProvider.instance.save()
                Task { @MainActor in
                    ModelProvider.instance.searchText = ""
                }
            }
        }
    }
    
    func open(query: String) {
        self.openedRecords[query, default: 0] += 1
        withErrorPresented {
            let path = self.item.appending(path: self.openableFileRelativePath)
            try await path.open()
            
            Task.detached {
                try ModelProvider.instance.save()
                Task { @MainActor in
                    ModelProvider.instance.searchText = ""
                }
            }
        }
    }
    
    func match(query: String) -> AttributedString? {
        let queryComponents = self.queryComponents
//        if self.mustIncludeFirstKeyword, case let .content(firstComponent) = queryComponents.first {
//            guard query.lowercased().hasPrefix(firstComponent.lowercased()) else { return nil }
//        }
        
//        var string = AttributedString(self.query)
//        if let range = string.range(of: query, options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive]) {
//            string[range].inlinePresentationIntent = .stronglyEmphasized
//            return string
//        }
        
//        if self.mustIncludeFirstKeyword, case let .content(firstComponent) = queryComponents.first {
//            // consume the first query component
//            query.removeFirst(firstComponent.count)
//            var attributed = AttributedString(firstComponent)
//            attributed.inlinePresentationIntent = .stronglyEmphasized
//            queryComponents.removeFirst()
//            resultingString.append(attributed)
//        }
        
        return __recursiveMatch(_query: query[query.startIndex...], components: queryComponents[0...], isFirst: true)
    }
    
    private func __recursiveMatch(_query: Substring, components: ArraySlice<QueryComponent>, isFirst: Bool = false) -> AttributedString? {
        guard !_query.isEmpty else {
            return AttributedString(components.map(\.value).joined(separator: "")) // end, returning trailing components
        }
        guard let component = components.first else {
            // reached end of components
            return nil
        }
        var query = _query
        
        switch component {
        case .spacer(let spacer):
            var attributed = AttributedString(String(spacer))
            if spacer.lowercased() == query.first?.lowercased() {
                query.removeFirst()
                attributed.inlinePresentationIntent = .stronglyEmphasized
            }
            return __recursiveMatch(_query: query, components: components.dropFirst()).map { attributed + $0 }
            
        case .content(let content):
            if query.first == "_" || (!query.isEmpty && query.first!.isWhitespace) {
                // okay. maybe we should ignore the white space, maybe we should keep it
                // prefer keep it
                
                // if keep it, then this content cannot be matched, skipped.
                if components.count != 1,
                   let next = __recursiveMatch(_query: query, components: components.dropFirst()) {
                    return AttributedString(content)  + next
                }
                
                // still here? then cannot keep it
                if let next = __recursiveMatch(_query: query.dropFirst(), components: components) {
                    return next
                }
                
                // no? then no match
                return nil
            }
            
            var contentIterator = content.makeIterator()
            var attributed = AttributedString()
            while let c = contentIterator.next() {
                if c.lowercased() == query.first?.lowercased() {
                    query.removeFirst()
                    var _attributed = AttributedString(String(c))
                    _attributed.inlinePresentationIntent = .stronglyEmphasized
                    attributed += _attributed
                } else {
                    if attributed.runs.isEmpty {
                        if self.mustIncludeFirstKeyword && isFirst {
                            return nil
                        }
                        // does not match at all
                        return __recursiveMatch(_query: query, components: components.dropFirst()).map { AttributedString(content) + $0 }
                    }
                    var cx = String(c)
                    while let next = contentIterator.next() { cx.append(next) }
                    attributed += AttributedString(cx)
                    break
                }
            }
            
            return __recursiveMatch(_query: query, components: components.dropFirst()).map({ attributed + $0 }) ?? (isFirst && self.mustIncludeFirstKeyword ? nil : __recursiveMatch(_query: _query, components: components.dropFirst()).map({ AttributedString(content) + $0 }))
        }
    }
    
    func delete() throws {
        try FinderItem(at: ModelProvider.storageLocation).enclosingFolder.appending(path: "icons").appending(path: "\(self.icon.id).heic").removeIfExists()
        try FinderItem(at: ModelProvider.storageLocation).enclosingFolder.appending(path: "bookmarks").appending(path: self.id.description).removeIfExists()
        
        self.isItemUpdated = true
        self.icon.isUpdated = true
    }
    
    /// An icon, remember to resize the icon to 32 x 32
    final class Icon: Codable {
        
        var image: NativeImage? {
            didSet {
                isUpdated = true
                Task.detached {
                    try FinderItem(at: ModelProvider.storageLocation).enclosingFolder.appending(path: "icons").appending(path: "\(self.id).heic").removeIfExists()
                }
            }
        }
        
        var isUpdated: Bool = false
        
        let id: UUID
        
        
        func encode(to encoder: Encoder) throws {
            let date = Date()
            defer { print("encode icon took \(date.distanceToNow())") }
            
            var container = encoder.singleValueContainer()
            
            guard image != nil else { try container.encodeNil(); return }
            try container.encode(id)
            
            guard isUpdated else { return }
            
            let iconDir = FinderItem(at: ModelProvider.storageLocation).enclosingFolder.appending(path: "icons")
            try image?.write(to: iconDir.appending(path: "\(id).heic"), option: .heic)
            self.isUpdated = false
        }
        
        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            guard !container.decodeNil() else {
                self.id = UUID()
                return
            }
            let id = try container.decode(UUID.self)
            guard let image = NativeImage(at: FinderItem(at: ModelProvider.storageLocation).enclosingFolder.appending(path: "icons").appending(path: "\(id).heic")) else { throw ErrorManager("Cannot decode the image") }
            self.image = image
            self.id = id
        }
        
        init(image: NativeImage?) {
            self.image = image
            self.id = UUID()
        }
        
        static let preview = Icon(image: NativeImage())
    }
    
    enum QueryComponent: Codable {
        
        case spacer(String)
        
        case content(String)
        
        
        var value: String {
            switch self {
            case .spacer(let string):
                return string
            case .content(let string):
                return string
            }
        }
        
    }
    
    init(query: String, item: FinderItem, openableFileRelativePath: String) {
        self.id = UUID()
        self.query = query
        self.item = item
        self.openableFileRelativePath = openableFileRelativePath
        self.icon = Icon(image: nil)
        self.openedRecords = [:]
        
        updateQueryComponents()
    }
    
    static let preview = QueryItem(query: "swift testRoom",
                                   item: FinderItem(at: "/Users/vaida/Library/Mobile Documents/com~apple~CloudDocs/DataBase/Swift/testRoom/testRoom"),
                                   openableFileRelativePath: "testRoom.xcodeproj")
    
    static func new() -> QueryItem {
        QueryItem(query: "new", item: .homeDirectory, openableFileRelativePath: "")
    }
    
    
    enum CodingKeys: CodingKey {
        case id
        case _query
        case _openableFileRelativePath
        case _icon
        case _iconSystemName
        case _openedCount
        case _mustIncludeFirstKeyword
        case _queryComponents
        case _openedRecords
    }
    
    func encode(to encoder: Encoder) throws {
        let date = Date()
        defer { print("encode query item took \(date.distanceToNow())") }
        
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
        try container.encode(self._openedRecords, forKey: ._openedRecords)
        try container.encode(self._mustIncludeFirstKeyword, forKey: ._mustIncludeFirstKeyword)
        try container.encode(self._queryComponents, forKey: ._queryComponents)
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
        self._icon = try container.decode(QueryItem.Icon.self, forKey: ._icon)
        self._iconSystemName = try container.decode(String.self, forKey: ._iconSystemName)
        self._openedRecords = try container.decodeIfPresent([String:Int].self, forKey: ._openedRecords) ?? [:]
        self._mustIncludeFirstKeyword = try container.decode(Bool.self, forKey: ._mustIncludeFirstKeyword)
        self._queryComponents = try container.decode([QueryItem.QueryComponent].self, forKey: ._queryComponents)
    }
}
