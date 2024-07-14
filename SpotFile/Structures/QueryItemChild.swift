//
//  QueryItemChild.swift
//  SpotFile
//
//  Created by Vaida on 2024/2/28.
//

import Foundation
import Stratum
import SwiftData
import OSLog


final class QueryItemChild: Codable, Identifiable, QueryItemProtocol, CustomStringConvertible {
    
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
    
    /// The top level QueryItem parent.
    var queryItem: QueryItem {
        if let parent = parent as? QueryItem {
            return parent
        } else {
            return (parent as! QueryItemChild).queryItem
        }
    }
    
    let openableFileRelativePath: String
    
    var iconSystemName: String { "" }
    
    var description: String {
        "QueryItemChild<parent: \(self.queryItem), relative: \(self.openableFileRelativePath)>"
    }
    
    
    func updateRecords(_ query: String, context: ModelContext) {
        let parentID = self.queryItem.id
        let search = String(query.dropFirst(while: { $0.isWhitespace }))
        
        do {
            let relativePath = self.openableFileRelativePath
            let models = try context.fetch(FetchDescriptor<QueryChildRecord>(predicate: #Predicate { $0.parentID == parentID && $0.relativePath == relativePath })).filter({ search.starts(with: $0.query) })
            if !models.isEmpty {
                assert(models.count == 1)
                models[0].count += 1
            } else {
                context.insert(QueryChildRecord(parentID: parentID, query: search, relativePath: self.openableFileRelativePath, count: 1))
            }
        } catch {
            let logger = Logger(subsystem: "SpotFile", category: "updateRecords")
            logger.error("updateRecords encountered error: \(error)")
        }
        
        try! context.save()
    }
    
    
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
