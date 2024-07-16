//
//  UnmatchedSearch.swift
//  SpotFile
//
//  Created by Vaida on 7/16/24.
//

import Foundation
import SwiftData


@Model
final class UnmatchedSearch {
    
    /// Query.content
    @Attribute(.unique)
    let query: String
    
    @Relationship(deleteRule: .cascade)
    let unmatchedPrefixes: UnmatchedPrefixes
    
    
    init(query: String, unmatchedPrefixes: UnmatchedPrefixes) {
        self.query = query
        self.unmatchedPrefixes = unmatchedPrefixes
    }
    
    
    @Model
    final class UnmatchedPrefixes {
        
        var prefixes: [String]
        
        init(prefixes: [String]) {
            self.prefixes = prefixes
        }
        
    }
    
}
