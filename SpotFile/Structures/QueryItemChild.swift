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
    
    unowned var parent: QueryItem!
    
    
    var query: String {
        self.parent.query + "/" + self.openableFileRelativePath
    }
    
    var item: FinderItem {
        self.parent.item
    }
    
    let openableFileRelativePath: String
    
    var mustIncludeFirstKeyword: Bool {
        self.parent.mustIncludeFirstKeyword
    }
    
    var icon: Icon {
        self.parent.icon
    }
    
    var iconSystemName: String {
        self.parent.iconSystemName
    }
    
    var openedRecords: [String : Int]
    
    lazy var queryComponents: [QueryComponent] = self.updateQueryComponents()
    
    
    init(parent: QueryItem, openableFileRelativePath: String, openedRecords: [String : Int]) {
        self.parent = parent
        self.openableFileRelativePath = openableFileRelativePath
        self.openedRecords = openedRecords
    }
    
    enum CodingKeys: CodingKey {
        case openableFileRelativePath
        case openedRecords
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(self.openableFileRelativePath, forKey: .openableFileRelativePath)
        try container.encode(self.openedRecords, forKey: .openedRecords)
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.openableFileRelativePath = try container.decode(String.self, forKey: .openableFileRelativePath)
        self.openedRecords = try container.decode([String : Int].self, forKey: .openedRecords)
        self.parent = nil
    }
    
}
