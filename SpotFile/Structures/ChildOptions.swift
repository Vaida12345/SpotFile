//
//  ChildOptions.swift
//  SpotFile
//
//  Created by Vaida on 5/17/24.
//

import Foundation
import StratumMacros
import Stratum


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
        
        @encodeOptions(.encodeIfNoneDefault)
        var plainRelativePath: String = ""
        
        /// The relative path to open. when not exist, the file / folder would be opened / shown.
        @transient
        var relativePath: Regex<Substring>? = nil
        
        @transient
        var filters: [Regex<Substring>] = []
        
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
            
            guard cumulative.isEmpty || !opened else {
                throw FilerError.unclosedSlash
            }
        }
        
        mutating func updateRelativePath() throws {
            self.relativePath = try Regex(plainRelativePath + "/?")
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
            try self.updateRelativePath()
        }
        
        enum FilerError: LocalizableError {
            case unclosedSlash
            
            var titleResource: LocalizedStringResource {
                "Parse Filer Error"
            }
            
            var messageResource: LocalizedStringResource {
                switch self {
                case .unclosedSlash:
                    "Expected \"/\"."
                }
            }
        }
        
        init(isDirectory: Bool = false, isEnabled: Bool = false, includeFolder: Bool = true, includeFile: Bool = false, enumeration: Bool = true, filterBy: String = "", relativePath: Regex<Substring>? = nil, filters: [Regex<Substring>] = []) {
            self.isDirectory = isDirectory
            self.isEnabled = isEnabled
            self.includeFolder = includeFolder
            self.includeFile = includeFile
            self.enumeration = enumeration
            self.filterBy = filterBy
            self.relativePath = relativePath
            self.filters = filters
        }
        
    }
    
}
