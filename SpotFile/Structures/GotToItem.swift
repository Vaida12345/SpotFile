//
//  GotToItem.swift
//  SpotFile
//
//  Created by Vaida on 7/14/24.
//

import Foundation
import FinderItem
import SwiftData


final class GoToItem: QueryItemProtocol {
    
    let id: UUID = UUID()
    
    /// This value should never access
    var query: Query {
        Query(value: "")
    }
    
    let item: FinderItem
    
    var openableFileRelativePath: String {
        ""
    }
    
    let iconSystemName: String
    
    func updateRecords(_ query: String, context: ModelContext) {
        // do nothing
    }
    
    init(item: FinderItem, iconSystemName: String) {
        self.item = item
        self.iconSystemName = iconSystemName
    }
    
}
