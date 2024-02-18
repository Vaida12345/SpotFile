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
    
    var iconView: Image {
        if !self.iconSystemName.isEmpty {
            Image(systemName: self.iconSystemName)
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
    
    private func updateIcon() async throws {
        let icon = try await self.item.preview(size: .square(64))
        self.icon.image = icon
    }
    
    func open() {
        self.openedCount += 1
        Task {
            do {
                let path = self.item.appending(path: self.openableFileRelativePath)
                if path.isDirectory {
                    try path.reveal()
                } else {
                    try await path.open()
                }
//                print(path)
//                if path.extension == "xcodeproj", let xcodePath = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.dt.Xcode") {
//                    let config = NSWorkspace.OpenConfiguration()
//                    config.activates = true
//                    
//                    let app = try await NSWorkspace.shared.open([path.url], withApplicationAt: xcodePath.appending(path: "Contents/MacOS/Xcode"), configuration: config)
//                    print(app)
//                    print(app.isActive)
//                    print(app.isFinishedLaunching)
//                    print(app.isHidden)
//                    print(app.isTerminated)
//                    print(app.launchDate)
//                    print(app.processIdentifier)
//                } else {
//                    print(try await path.open())
//                }
            } catch {
                await AlertManager(error).present()
            }
        }
    }
    
    func match(query: String) -> AttributedString? {
        var queryComponents = self.queryComponents
        if self.mustIncludeFirstKeyword, case let .content(firstComponent) = queryComponents.first {
            guard query.lowercased().hasPrefix(firstComponent.lowercased()) else { return nil }
        }
        
//        var string = AttributedString(self.query)
//        if let range = string.range(of: query, options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive]) {
//            string[range].inlinePresentationIntent = .stronglyEmphasized
//            return string
//        }
        
        var resultingString = AttributedString()
        var query = query
        
        if self.mustIncludeFirstKeyword, case let .content(firstComponent) = queryComponents.first {
            // consume the first query component
            query.removeFirst(firstComponent.count)
            var attributed = AttributedString(firstComponent)
            attributed.inlinePresentationIntent = .stronglyEmphasized
            queryComponents.removeFirst()
            resultingString.append(attributed)
        }
        
        return __recursiveMatch(query: query[query.startIndex...], components: queryComponents[0...])
    }
    
    private func __recursiveMatch(query: Substring, components: ArraySlice<QueryComponent>) -> AttributedString? {
        guard !query.isEmpty else {
            return AttributedString(components.map(\.value).joined(separator: "")) // end, returning trailing components
        }
        guard let component = components.first else {
            // reached end of components
            return nil
        }
        var query = query
        
        switch component {
        case .spacer(let spacer):
            var attributed = AttributedString(String(spacer))
            if spacer.lowercased() == query.first?.lowercased() {
                query.removeFirst()
                attributed.inlinePresentationIntent = .stronglyEmphasized
            }
            return __recursiveMatch(query: query, components: components.dropFirst()).map { attributed + $0 }
            
        case .content(let content):
            if query.first == "_" || (!query.isEmpty && query.first!.isWhitespace) {
                // okay. maybe we should ignore the white space, maybe we should keep it
                // prefer keep it
                
                // if keep it, then this content cannot be matched, skipped.
                if components.count != 1,
                   let next = __recursiveMatch(query: query, components: components.dropFirst()) {
                    return AttributedString(content)  + next
                }
                
                // still here? then cannot keep it
                if let next = __recursiveMatch(query: query.dropFirst(), components: components) {
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
                        // does not match at all
                        return __recursiveMatch(query: query, components: components.dropFirst()).map { AttributedString(content) + $0 }
                    }
                    var cx = String(c)
                    while let next = contentIterator.next() { cx.append(next) }
                    attributed += AttributedString(cx)
                    break
                }
            }
            
            return __recursiveMatch(query: query, components: components.dropFirst()).map { attributed + $0 }
        }
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
        case _item
        case _openableFileRelativePath
        case _icon
        case _iconSystemName
        case _openedCount
        case _mustIncludeFirstKeyword
        case _queryComponents
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(self.id, forKey: .id)
        try container.encode(self._query, forKey: ._query)
        try container.encode(self._item, forKey: ._item, configuration: [])
        try container.encode(self._openableFileRelativePath, forKey: ._openableFileRelativePath)
        try container.encode(self._icon, forKey: ._icon)
        try container.encode(self._iconSystemName, forKey: ._iconSystemName)
        try container.encode(self._openedCount, forKey: ._openedCount)
        try container.encode(self._mustIncludeFirstKeyword, forKey: ._mustIncludeFirstKeyword)
        try container.encode(self._queryComponents, forKey: ._queryComponents)
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(UUID.self, forKey: .id)
        self._query = try container.decode(String.self, forKey: ._query)
        self._item = try container.decode(FinderItem.self, forKey: ._item, configuration: [])
        self._openableFileRelativePath = try container.decode(String.self, forKey: ._openableFileRelativePath)
        self._icon = try container.decode(QueryItem.Icon.self, forKey: ._icon)
        self._iconSystemName = try container.decode(String.self, forKey: ._iconSystemName)
        self._openedCount = try container.decode(Int.self, forKey: ._openedCount)
        self._mustIncludeFirstKeyword = try container.decode(Bool.self, forKey: ._mustIncludeFirstKeyword)
        self._queryComponents = try container.decode([QueryItem.QueryComponent].self, forKey: ._queryComponents)
    }
}
