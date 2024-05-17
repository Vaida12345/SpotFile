//
//  QueryItem.swift
//  SpotFile
//
//  Created by Vaida on 2024/2/4.
//

import Foundation
import Stratum
import SwiftUI
import StratumMacros


@Observable
@codable
final class QueryItem: Codable, Identifiable, QueryItemProtocol {
    
    let id: UUID = UUID()
    
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
}
