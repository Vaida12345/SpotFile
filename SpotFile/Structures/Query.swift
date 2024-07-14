//
//  Query.swift
//  SpotFile
//
//  Created by Vaida on 2024/3/4.
//

import Foundation
import SwiftUI
import StratumMacros


@codable
struct Query: Identifiable, CustomStringConvertible {
    
    let id = UUID()
    
    var content: String {
        didSet {
            updateComponents()
        }
    }
    
    /// the returned components are NOT lowercased
    @ObservationIgnored
    @transient
    var components: [Component] = []
    
    var mustIncludeFirstKeyword: Bool
    
    var description: String {
        self.content
    }
    
    
    mutating func updateComponents() {
        self.components = Query.component(for: self.content)
    }
    
    static func component(for value: String) -> [Component] {
        var components: [Component] = []
        
        var index = value.startIndex
        var cumulative = ""
        var isNumber = value.first?.isNumber ?? false
        
        while index < value.endIndex {
            if (value[index].isUppercase && !cumulative.isEmpty && !cumulative.allSatisfy(\.isUppercase)) || isNumber != value[index].isNumber {
                components.append(.content(cumulative))
                cumulative = ""
                isNumber = value[index].isNumber
                continue
            } else if value[index].isWhitespace || QueryItem.separators.contains(value[index]) {
                components.append(.content(cumulative))
                components.append(.spacer("\(value[index])"))
                cumulative = ""
                value.formIndex(after: &index)
                continue
            }
            
            cumulative.append(value[index])
            value.formIndex(after: &index)
        }
        
        if !cumulative.isEmpty {
            components.append(.content(cumulative))
        }
        
        return components
    }
    
    
    func match(query: String, isChild: Bool) -> Text? {
        let queryComponents = self.components
        let query = Array(query.lowercased()) // use array, as array is `RandomAccessCollection`.
        
        if queryComponents.count == 1 && !isChild, case let .content(content) = queryComponents.first { // is only, special case: allow jump-match
            var cumulative = Text("")
            var query = query
            var index = content.startIndex
            
            while index < content.endIndex {
                let c = content[index]
                if c.lowercased().first == query.first {
                    query.removeFirst()
                    cumulative = cumulative + Text("\(c)").bold()
                } else {
                    cumulative = cumulative + Text("\(c)")
                }
                
                content.formIndex(after: &index)
            }
            
            return query.isEmpty ? cumulative : nil
        }
        
        return __recursiveMatch(_query: query[query.startIndex...], components: queryComponents[0...], isFirst: true)
    }
    
    private func __recursiveMatch(_query: ArraySlice<Character>, components: ArraySlice<Component>, isFirst: Bool = false) -> Text? {
        guard !_query.isEmpty else {
            return Text(components.map(\.value).joined(separator: "")) // end, returning trailing components
        }
        guard let component = components.first else {
            // reached end of components
            return nil
        }
        var query = _query
        
        switch component {
        case .spacer(let spacer):
            var shouldEmphasize = false
            if spacer.first == query.first {
                query.removeFirst()
                shouldEmphasize = true
            }
            
            return __recursiveMatch(_query: query, components: components.dropFirst()).map {
                return Text(spacer).bold(shouldEmphasize) + $0
            }
            
        case .content(let content):
            if QueryItem.separators.contains(query.first!) || query.first!.isWhitespace { // query cannot be empty, as ensured by the guard on the first line
                                                                                          // okay. maybe we should ignore the white space, maybe we should keep it
                                                                                          // prefer keep it
                
                // if keep it, then this content cannot be matched, skipped.
                if components.count != 1,
                   let next = __recursiveMatch(_query: query, components: components.dropFirst()) {
                    return Text(content) + next
                }
                
                // still here? then cannot keep it
                if let next = __recursiveMatch(_query: query.dropFirst(), components: components) {
                    return next
                }
                
                // no? then no match
                return nil
            }
            
            var cumulative = ""
            var remaining = Substring()
            
            var index = content.startIndex
            while index < content.endIndex {
                let c = content[index]
                if c.lowercased().first == query.first {
                    query.removeFirst()
                    cumulative.append(c)
                } else {
                    if cumulative.isEmpty {
                        if self.mustIncludeFirstKeyword && isFirst {
                            return nil
                        }
                        // does not match at all
                        return __recursiveMatch(_query: query, components: components.dropFirst()).map { Text(content) + $0 }
                    }
                    remaining = content[index...]
                    break
                }
                
                content.formIndex(after: &index)
            }
            
            
            if let match = __recursiveMatch(_query: query, components: components.dropFirst()) {
                let attributed = Text(cumulative).bold() + Text(remaining)
                return attributed + match
            } else if isFirst && self.mustIncludeFirstKeyword {
                return nil
            } else if let match = __recursiveMatch(_query: _query, components: components.dropFirst()) { // unconsumed, original query
                let attributed = Text(content)
                return attributed + match
            } else {
                return nil
            }
        }
    }
    
    
    // MARK: - Substructures
    
    enum Component: Codable {
        
        /// Spacer should **always** be `Character`
        case spacer(String)
        
        case content(String)
        
        
        var value: String {
            switch self {
            case .spacer(let string):
                return string
            case .content(let string):
                return string
            }
        }
        
    }

    
    
    // MARK: - Coding & Initializers
    
    /// The post decode action which will be called at the end of auto generated `init(from:)` by the `codable` macro.
    mutating func postDecodeAction() throws {
        self.updateComponents()
    }
    
    init(value: String, mustIncludeFirstKeyword: Bool = false) {
        self.content = value
        self.mustIncludeFirstKeyword = mustIncludeFirstKeyword
        self.updateComponents()
    }
    
    init(value: String, mustIncludeFirstKeyword: Bool, queryComponents: [Component]) {
        self.content = value
        self.mustIncludeFirstKeyword = mustIncludeFirstKeyword
        self.components = queryComponents
    }
    
}
