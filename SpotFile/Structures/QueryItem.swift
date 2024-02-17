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
            Task {
                try await updateIcon()
            }
        }
    }
    
    var openableFileRelativePath: String
    
    var icon: Icon
    
    var iconSystemName: String = ""
    
    
    var openedCount: Int = 0
    
    var mustIncludeFirstKeyword = false
    
    
    /// the returned components are lowercased.
    var queryComponents: [QueryComponent] = []
    
    private func updateQueryComponents() {
        var components: [QueryComponent] = []
        
        var index = self.query.startIndex
        var startIndex = index
        var cumulative = ""
        
        while index < self.query.endIndex {
            if (self.query[index].isUppercase && !cumulative.isEmpty && !cumulative.allSatisfy(\.isUppercase)) {
                components.append(QueryComponent(cumulative.lowercased(), startIndex, index, parent: self.query))
                cumulative = ""
                startIndex = index
                continue
            } else if self.query[index].isWhitespace || self.query[index] == "_" {
                components.append(QueryComponent(cumulative.lowercased(), startIndex, index, parent: self.query))
                cumulative = ""
                self.query.formIndex(after: &index)
                startIndex = index
                continue
            }
            
            cumulative.append(self.query[index])
            self.query.formIndex(after: &index)
        }
        
        if !cumulative.isEmpty {
            components.append(QueryComponent(cumulative.lowercased(), startIndex, self.query.endIndex, parent: self.query))
        }
        
        queryComponents = components
    }
    
    private func updateIcon() async throws {
        let icon = try await self.item.preview(size: .square(64))
        self.icon.image = icon
    }
    
    func match(query: String) -> AttributedString? {
        var queryComponents = self.queryComponents
        if self.mustIncludeFirstKeyword, let firstComponent = queryComponents.first {
            guard query.hasPrefix(firstComponent.value) else { return nil }
        }
        
        var string = AttributedString(self.query)
        if let range = string.range(of: query, options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive]) {
            string[range].inlinePresentationIntent = .stronglyEmphasized
            return string
        }
        
        var resultingString = AttributedString()
        var query = query
        
        if self.mustIncludeFirstKeyword, !queryComponents.isEmpty {
            // consume the first query component
            query.removeFirst(queryComponents.first!.value.count)
            var attributed = AttributedString(self.query[self.query.startIndex ..< queryComponents.removeFirst().endIndex])
            attributed.inlinePresentationIntent = .stronglyEmphasized
            resultingString.append(attributed)
        }
        
        var queryIterator = query.makeIterator()
        var queryIteratorCurrent: Character? = nil
        
        func assignNext() -> Bool {
            guard let next = queryIterator.next() else { return false }
            if next.isWhitespace || next == "_" { return assignNext() }
            queryIteratorCurrent = next
            return true
        }
        
        
        for (component, startIndex, endIndex) in queryComponents.map(\.tuple) {
            for c in component {
                if queryIteratorCurrent == c {
                    
                    guard assignNext() else {
                        
                    }
                }
            }
            
            
        }
        
        return nil
    }
    
    /// An icon, remember to resize the icon to 32 x 32
    struct Icon: Codable {
        
        var image: NativeImage?
        
        func encode(to encoder: Encoder) throws {
            var container = encoder.singleValueContainer()
            try container.encode(image?.data(using: .heic))
        }
        
        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            guard !container.decodeNil() else { return }
            let data = try container.decode(Data.self)
            guard let image = NativeImage(data: data) else { throw ErrorManager("Cannot decode the image") }
            self.image = image
        }
        
        init(image: NativeImage?) {
            self.image = image
        }
        
        static let preview = Icon(image: NativeImage())
    }
    
    struct QueryComponent: Codable {
        
        let parent: String
        
        let value: String
        
        let startIndex: String.Index
        
        let endIndex: String.Index
        
        var tuple: (String, String.Index, String.Index) {
            (value, startIndex, endIndex)
        }
        
        init(_ value: String, startIndex: String.Index, endIndex: String.Index, parent: String) {
            self.value = value
            self.startIndex = startIndex
            self.endIndex = endIndex
            self.parent = parent
        }
        
        init(_ value: String, _ startIndex: String.Index, _ endIndex: String.Index, parent: String) {
            self.value = value
            self.startIndex = startIndex
            self.endIndex = endIndex
            self.parent = parent
        }
        
        
        enum CodingKeys: CodingKey {
            case value
            case startIndex
            case endIndex
            case parent
        }
        
        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            
            try container.encode(value, forKey: .value)
            try container.encode(startIndex.utf16Offset(in: parent), forKey: .startIndex)
            try container.encode(endIndex.utf16Offset(in: parent), forKey: .endIndex)
            try container.encode(parent, forKey: .parent)
        }
        
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            self.parent = try container.decode(String.self, forKey: .parent)
            self.value = try container.decode(String.self, forKey: .value)
            let _startIndex = try container.decode(Int.self, forKey: .startIndex)
            self.startIndex = .init(utf16Offset: _startIndex, in: self.parent)
            let _endIndex = try container.decode(Int.self, forKey: .endIndex)
            self.endIndex = .init(utf16Offset: _endIndex, in: self.parent)
        }
        
    }
    
    init(query: String, item: FinderItem, openableFileRelativePath: String) {
        self.id = UUID()
        self.query = query
        self.item = item
        self.openableFileRelativePath = openableFileRelativePath
        self.icon = Icon(image: nil)
    }
    
    static let preview = QueryItem(query: "swift testRoom",
                                   item: FinderItem(at: "/Users/vaida/Library/Mobile Documents/com~apple~CloudDocs/DataBase/Swift/testRoom/testRoom"),
                                   openableFileRelativePath: "testRoom.xcodeproj")
    
    static func new() -> QueryItem {
        QueryItem(query: "new", item: .homeDirectory, openableFileRelativePath: "")
    }
}
