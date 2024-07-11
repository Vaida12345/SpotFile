//
//  QueryItemChild.swift
//  SpotFile
//
//  Created by Vaida on 2024/2/28.
//

import Foundation
import Stratum


final class QueryItemChild: Codable, Identifiable, QueryItemProtocol {
    
    let id = UUID()
    
    let parent: (any QueryItemProtocol)! // no need unown, wont be circular anyway
    
    
    var query: Query {
        if parent is QueryItem {
            Query(value: self.openableFileRelativePath, 
                  mustIncludeFirstKeyword: false)
        } else {
            Query(value: self.parent.query.content + "/" + self.openableFileRelativePath, 
                  mustIncludeFirstKeyword: false,
                  queryComponents: self.parent.query.components + [.spacer("/")] + Query.component(for: self.openableFileRelativePath))
        }
    }
    
    var item: FinderItem {
        self.parent.item.appending(path: openableFileRelativePath)
    }
    
    var queryItem: QueryItem {
        if let parent = parent as? QueryItem {
            return parent
        } else {
            return (parent as! QueryItemChild).queryItem
        }
    }
    
    let openableFileRelativePath: String
    
    var iconSystemName: String { "" }
    
    @ObservationIgnored
    var openedRecords: [String: Int] = [:]
    
    
    init(parent: any QueryItemProtocol, filename: String) {
        self.parent = parent
        self.openableFileRelativePath = filename
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(self.openableFileRelativePath)
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        self.openableFileRelativePath = try container.decode(String.self)
        self.parent = nil
    }
    
    static let preview = QueryItemChild(parent: QueryItem.preview, filename: "folder/file.png")
    
}
