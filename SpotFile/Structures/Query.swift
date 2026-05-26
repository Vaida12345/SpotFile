//
//  Query.swift
//  SpotFile
//
//  Created by Vaida on 2024/3/4.
//

import Foundation
import SwiftUI
import MacroCollection
import Essentials


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
    private(set) var components: [Component] = []
    
    @ObservationIgnored
    @transient
    private(set) var computes: [Compute] = []
    
    @ObservationIgnored
    @transient
    var lowercasedContent: String = ""

    var mustIncludeFirstKeyword: Bool

    var description: String {
        self.content
    }


    private mutating func updateComponents() {
        self.components = Query.component(for: self.content)
        self.computes = self.components.map(\.compute)
        self.lowercasedContent = self.content.lowercased()
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
                components.append(.spacer(value[index]))
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


    // MARK: - Boolean-only matching (no Text allocation)

    func matches(lowercasedQueryChars: [Character], isChild: Bool) -> Bool {
        var queryComponents = self.computes

        if queryComponents.count == 1 && !isChild, case let .content(content) = queryComponents.first {
            var query = lowercasedQueryChars
            var index = content.startIndex
            while index < content.endIndex {
                if content[index] == query.first {
                    query.removeFirst()
                }
                content.formIndex(after: &index)
            }
            return query.isEmpty
        }
        
        var queryBuffer = lowercasedQueryChars
        return queryBuffer.withUnsafeMutableBufferPointer { queryBuffer in
            queryComponents.withUnsafeMutableBufferPointer { componentsBuffer in
                __recursiveMatchBoolean(_query: queryBuffer, components: componentsBuffer, isFirst: true)
            }
        }
    }

    private func __recursiveMatchBoolean(_query: UnsafeMutableBufferPointer<Character>, components: UnsafeMutableBufferPointer<Compute>, isFirst: Bool = false) -> Bool {
        guard !_query.isEmpty else {
            return true
        }
        guard let component = components.first else {
            return false
        }
        let query = _query

        switch component {
        case .spacer(let spacer):
            let offset = spacer == query.first ? 1 : 0
            return __recursiveMatchBoolean(_query: query + offset, components: components + 1)

        case .content(let content):
            let first = query.first!
            if QueryItem.separators.contains(first) || first.isWhitespace {
                if components.count != 1,
                   __recursiveMatchBoolean(_query: query, components: components + 1) {
                    return true
                }
                if __recursiveMatchBoolean(_query: query + 1, components: components) {
                    return true
                }
                return false
            }

            var queryOffset = 0
            var hasConsumed = false
            var index = 0
            while index < content.count {
                let c = content[index]
                if queryOffset < query.count && c == query[queryOffset] {
                    queryOffset += 1
                    hasConsumed = true
                } else {
                    if !hasConsumed {
                        if self.mustIncludeFirstKeyword && isFirst {
                            return false
                        }
                        return __recursiveMatchBoolean(_query: query + queryOffset, components: components + 1)
                    }
                    break
                }
                index &+= 1
            }

            if __recursiveMatchBoolean(_query: query + queryOffset, components: components + 1) {
                return true
            } else if isFirst && self.mustIncludeFirstKeyword {
                return false
            } else if __recursiveMatchBoolean(_query: _query, components: components + 1) {
                return true
            } else {
                return false
            }
        }
    }


    // MARK: - Text-building matching (for display)

    func match(lowercasedQueryChars: [Character], isChild: Bool) -> Text? {
        let queryComponents = self.components

        if queryComponents.count == 1 && !isChild, case let .content(content) = queryComponents.first {
            var cumulative = Text("")
            var query = lowercasedQueryChars[...]
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

        let queryBuffer = UnsafeMutableBufferPointer<Character>.allocate(capacity: lowercasedQueryChars.count)
        defer { queryBuffer.deallocate() }
        _ = queryBuffer.initialize(fromContentsOf: lowercasedQueryChars)

        let componentsBuffer = UnsafeMutableBufferPointer<Component>.allocate(capacity: queryComponents.count)
        defer { componentsBuffer.deallocate() }
        _ = componentsBuffer.initialize(fromContentsOf: queryComponents)

        return __recursiveMatch(_query: queryBuffer, components: componentsBuffer, isFirst: true)
    }

    /// Convenience wrapper that handles String → [Character] conversion.
    func match(query: String, isChild: Bool) -> Text? {
        match(lowercasedQueryChars: Array(query.lowercased()), isChild: isChild)
    }

    private func __recursiveMatch(_query: UnsafeMutableBufferPointer<Character>, components: UnsafeMutableBufferPointer<Component>, isFirst: Bool = false) -> Text? {
        guard !_query.isEmpty else {
            return Text(components.map(\.value).joined(separator: ""))
        }
        guard let component = components.first else {
            return nil
        }
        let query = _query

        switch component {
        case .spacer(let spacer):
            let offset = spacer == query.first ? 1 : 0
            let shouldEmphasize = offset == 1
            return __recursiveMatch(_query: query + offset, components: components + 1).map {
                return Text(String(spacer)).bold(shouldEmphasize) + $0
            }

        case .content(let content):
            if QueryItem.separators.contains(query.first!) || query.first!.isWhitespace {
                if components.count != 1,
                   let next = __recursiveMatch(_query: query, components: components + 1) {
                    return Text(content) + next
                }

                if let next = __recursiveMatch(_query: query + 1, components: components) {
                    return next
                }

                return nil
            }

            var queryOffset = 0
            var cumulative = ""
            var remaining = Substring()

            var index = content.startIndex
            while index < content.endIndex {
                let c = content[index]
                if queryOffset < query.count && c.lowercased().first == query[queryOffset] {
                    queryOffset += 1
                    cumulative.append(c)
                } else {
                    if cumulative.isEmpty {
                        if self.mustIncludeFirstKeyword && isFirst {
                            return nil
                        }
                        return __recursiveMatch(_query: query + queryOffset, components: components + 1).map { Text(content) + $0 }
                    }
                    remaining = content[index...]
                    break
                }

                content.formIndex(after: &index)
            }


            if let match = __recursiveMatch(_query: query + queryOffset, components: components + 1) {
                let attributed = Text(cumulative).bold() + Text(remaining)
                return attributed + match
            } else if isFirst && self.mustIncludeFirstKeyword {
                return nil
            } else if let match = __recursiveMatch(_query: _query, components: components + 1) {
                let attributed = Text(content)
                return attributed + match
            } else {
                return nil
            }
        }
    }


    // MARK: - Substructures

    enum Component {
        case spacer(Character)
        case content(String)

        var value: String {
            switch self {
            case .spacer(let char):
                String(char)
            case .content(let string):
                string
            }
        }
        
        var compute: Compute {
            switch self {
            case .spacer(let character):
                Compute.spacer(character)
            case .content(let string):
                Compute.content(Array(string.precomposedStringWithCanonicalMapping.lowercased()))
            }
        }
    }
    
    enum Compute {
        case spacer(Character)
        case content([Character])
        
        var value: String {
            switch self {
            case .spacer(let char):
                String(char)
            case .content(let string):
                String(string)
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
        self.computes = self.components.map(\.compute)
        self.lowercasedContent = value.lowercased()
    }

}
