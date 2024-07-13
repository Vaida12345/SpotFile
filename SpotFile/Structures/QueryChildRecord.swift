//
//  QueryChildRecord.swift
//  SpotFile
//
//  Created by Vaida on 7/13/24.
//

import Foundation
import SwiftData


@Model
final class QueryChildRecord: CustomStringConvertible {
    
    let parentID: UUID
    
    let query: String
    
    let relativePath: String
    
    var count: Int
    
    
    init(parentID: UUID, query: String, relativePath: String, count: Int) {
        self.parentID = parentID
        self.query = query
        self.count = count
        self.relativePath = relativePath
    }
    
    
    var description: String {
        "QueryChildRecord<query: \(self.query), relativePath: \(self.relativePath)>"
    }
    
}
