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
    
    
    var query: String {
        if let parent = parent as? QueryItem {
            self.openableFileRelativePath
        } else {
            self.parent.query + "/" + self.openableFileRelativePath
        }
    }
    
    var item: FinderItem {
        self.parent.item.appending(path: openableFileRelativePath)
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
    
    lazy var queryComponents: [QueryComponent] = self.updateQueryComponents()
    
    func updateRecords(_ query: String) { }
    
    
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
    
}
