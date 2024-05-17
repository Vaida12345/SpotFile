//
//  ChildOptions.swift
//  SpotFile
//
//  Created by Vaida on 5/17/24.
//

import Foundation


extension QueryItem {
    
    struct ChildOptions: Codable {
        
        /// Whether this item is a directory, and not a package.
        var isDirectory: Bool = false
        
        var isEnabled: Bool = false
        
        var includeFolder: Bool = true
        
        var includeFile: Bool = false
        
        var enumeration: Bool = true
        
        var filterBy: String = ""
        
        /// The relative path to open. when not exist, the file / folder would be opened / shown.
        var relativePath: String = ""
        
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
        }
        
        func filterContains(_ string: String) -> Bool {
            guard !filters.isEmpty else { return true }
            for filter in filters {
                if string.wholeMatch(of: filter) != nil { return true }
            }
            return false
        }
        
        
        internal init(isDirectory: Bool = false,
                      isEnabled: Bool = false,
                      includeFolder: Bool = true,
                      includeFile: Bool = false,
                      enumeration: Bool = true,
                      relativePath: String = "",
                      filterBy: String = "") {
            self.isDirectory = isDirectory
            self.isEnabled = isEnabled
            self.includeFolder = includeFolder
            self.includeFile = includeFile
            self.enumeration = enumeration
            self.relativePath = relativePath
            self.filterBy = filterBy
        }
        
        enum CodingKeys: CodingKey {
            case isDirectory
            case isEnabled
            case includeFolder
            case includeFile
            case enumeration
            case filterBy
            case relativePath
        }
        
        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: QueryItem.ChildOptions.CodingKeys.self)
            try container.encode(self.isDirectory, forKey: QueryItem.ChildOptions.CodingKeys.isDirectory)
            try container.encode(self.isEnabled, forKey: QueryItem.ChildOptions.CodingKeys.isEnabled)
            try container.encode(self.includeFolder, forKey: QueryItem.ChildOptions.CodingKeys.includeFolder)
            try container.encode(self.includeFile, forKey: QueryItem.ChildOptions.CodingKeys.includeFile)
            try container.encode(self.enumeration, forKey: QueryItem.ChildOptions.CodingKeys.enumeration)
            try container.encode(self.relativePath, forKey: QueryItem.ChildOptions.CodingKeys.relativePath)
            try container.encode(self.filterBy, forKey: QueryItem.ChildOptions.CodingKeys.filterBy)
        }
        
        init(from decoder: Decoder) throws {
            let container: KeyedDecodingContainer<QueryItem.ChildOptions.CodingKeys> = try decoder.container(keyedBy: QueryItem.ChildOptions.CodingKeys.self)
            self.isDirectory = try container.decode(Bool.self, forKey: QueryItem.ChildOptions.CodingKeys.isDirectory)
            self.isEnabled = try container.decode(Bool.self, forKey: QueryItem.ChildOptions.CodingKeys.isEnabled)
            self.includeFolder = try container.decode(Bool.self, forKey: QueryItem.ChildOptions.CodingKeys.includeFolder)
            self.includeFile = try container.decode(Bool.self, forKey: QueryItem.ChildOptions.CodingKeys.includeFile)
            self.enumeration = try container.decode(Bool.self, forKey: QueryItem.ChildOptions.CodingKeys.enumeration)
            self.relativePath = try container.decodeIfPresent(String.self, forKey: QueryItem.ChildOptions.CodingKeys.relativePath) ?? ""
            self.filterBy = try container.decodeIfPresent(String.self, forKey: QueryItem.ChildOptions.CodingKeys.filterBy) ?? ""
            
            try self.updateFilters()
        }
        
    }
    
}
