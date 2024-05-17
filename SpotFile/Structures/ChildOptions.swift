//
//  ChildOptions.swift
//  SpotFile
//
//  Created by Vaida on 5/17/24.
//

import Foundation
import StratumMacros


extension QueryItem {
    
    @codable
    struct ChildOptions {
        
        /// Whether this item is a directory, and not a package.
        var isDirectory: Bool = false
        
        var isEnabled: Bool = false
        
        var includeFolder: Bool = true
        
        var includeFile: Bool = false
        
        var enumeration: Bool = true
        
        var filterBy: String = ""
        
        /// The relative path to open. when not exist, the file / folder would be opened / shown.
        var relativePath: String = ""
        
        @transient
        var filters: [Regex<Substring>] = []
        
        
        mutating func postDecodeHandler() throws {
            try self.updateFilters()
        }
        
        
        mutating func updateFilters() throws {
            var cumulative = ""
            var opened = false
            for c in filterBy {
                if c == "/" {
                    if opened {
                        try filters.append(Regex(cumulative))
                        cumulative = ""
                    }
                    opened.toggle()
                } else if !opened {
                    continue
                } else {
                    cumulative.append(c)
                }
            }
        }
        
        func filterContains(_ string: String) -> Bool {
            guard !filters.isEmpty else { return true }
            for filter in filters {
                if string.wholeMatch(of: filter) != nil { return true }
            }
            return false
        }
        
        /// The post decode action which will be called at the end of auto generated `init(from:)` by the `codable` macro.
        mutating func postDecodeAction() throws {
            try self.updateFilters()
        }
        
    }
    
}
