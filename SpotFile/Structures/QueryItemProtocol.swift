//
//  QueryItemProtocol.swift
//  SpotFile
//
//  Created by Vaida on 2024/2/28.
//


import SwiftUI
import Stratum


protocol QueryItemProtocol: AnyObject {
    
    var id: UUID { get }
    
    var query: String { get }
    
    var item: FinderItem { get }
    
    var openableFileRelativePath: String { get }
    
    var mustIncludeFirstKeyword: Bool { get }
    
    var icon: Icon { get }
    
    var iconSystemName: String { get }
    
    var openedRecords: [String: Int] { get set }
    
    
    /// the returned components are lowercased.
    var queryComponents: [QueryComponent] { get }
    
}


extension QueryItemProtocol {
    
    @ViewBuilder
    func smallIconView(isSelected: Bool) -> some View {
        if !self.iconSystemName.isEmpty {
            if self.iconSystemName == "xcodeproj" {
                Image(.xcodeproj)
                    .imageScale(.large)
                    .foregroundStyle(isSelected ? .white : .blue)
            } else if self.iconSystemName == "xcodeproj.fill" {
                Image(.xcodeprojFill)
                    .imageScale(.large)
                    .foregroundStyle(isSelected ? .white : .blue)
            } else {
                Image(systemName: self.iconSystemName)
            }
        } else if let image = self.icon.image {
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
        } else {
            Image(systemName: "folder.badge.plus")
        }
    }
    
    var iconView: Image {
        if !self.iconSystemName.isEmpty {
            if self.iconSystemName == "xcodeproj" {
                Image(.xcodeproj)
            } else if self.iconSystemName == "xcodeproj.fill" {
                Image(.xcodeprojFill)
            } else {
                Image(systemName: self.iconSystemName)
            }
        } else if let image = self.icon.image {
            Image(nsImage: image)
        } else {
            Image(systemName: "folder.badge.plus")
        }
    }
    
    
    
    func updateQueryComponents() -> [QueryComponent] {
        var components: [QueryComponent] = []
        
        var index = self.query.startIndex
        var cumulative = ""
        
        while index < self.query.endIndex {
            if (self.query[index].isUppercase && !cumulative.isEmpty && !cumulative.allSatisfy(\.isUppercase)) {
                components.append(.content(cumulative))
                cumulative = ""
                continue
            } else if self.query[index].isWhitespace || QueryItem.separators.contains(self.query[index]) {
                components.append(.content(cumulative))
                components.append(.spacer("\(self.query[index])"))
                cumulative = ""
                self.query.formIndex(after: &index)
                continue
            }
            
            cumulative.append(self.query[index])
            self.query.formIndex(after: &index)
        }
        
        if !cumulative.isEmpty {
            components.append(.content(cumulative))
        }
        
        return components
    }
    
    
    func match(query: String) -> AttributedString? {
        let queryComponents = self.queryComponents
        //        if self.mustIncludeFirstKeyword, case let .content(firstComponent) = queryComponents.first {
        //            guard query.lowercased().hasPrefix(firstComponent.lowercased()) else { return nil }
        //        }
        
        //        var string = AttributedString(self.query)
        //        if let range = string.range(of: query, options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive]) {
        //            string[range].inlinePresentationIntent = .stronglyEmphasized
        //            return string
        //        }
        
        //        if self.mustIncludeFirstKeyword, case let .content(firstComponent) = queryComponents.first {
        //            // consume the first query component
        //            query.removeFirst(firstComponent.count)
        //            var attributed = AttributedString(firstComponent)
        //            attributed.inlinePresentationIntent = .stronglyEmphasized
        //            queryComponents.removeFirst()
        //            resultingString.append(attributed)
        //        }
        
        return __recursiveMatch(_query: query[query.startIndex...], components: queryComponents[0...], isFirst: true)
    }
    
    private func __recursiveMatch(_query: Substring, components: ArraySlice<QueryComponent>, isFirst: Bool = false) -> AttributedString? {
        let date = Date()
        defer { print("one iteration took \(date.distanceToNow())") }
        
        guard !_query.isEmpty else {
            return AttributedString(components.map(\.value).joined(separator: "")) // end, returning trailing components
        }
        guard let component = components.first else {
            // reached end of components
            return nil
        }
        var query = _query
        
        switch component {
        case .spacer(let spacer):
            var attributed = AttributedString(String(spacer))
            if spacer.lowercased() == query.first?.lowercased() {
                query.removeFirst()
                attributed.inlinePresentationIntent = .stronglyEmphasized
            }
            return __recursiveMatch(_query: query, components: components.dropFirst()).map { attributed + $0 }
            
        case .content(let content):
            if QueryItem.separators.contains(query.first!) || query.first!.isWhitespace { // query cannot be empty, as ensured by the guard on the first line
                  // okay. maybe we should ignore the white space, maybe we should keep it
                  // prefer keep it
                
                // if keep it, then this content cannot be matched, skipped.
                if components.count != 1,
                   let next = __recursiveMatch(_query: query, components: components.dropFirst()) {
                    return AttributedString(content)  + next
                }
                
                // still here? then cannot keep it
                if let next = __recursiveMatch(_query: query.dropFirst(), components: components) {
                    return next
                }
                
                // no? then no match
                return nil
            }
            
            var contentIterator = content.makeIterator()
            var attributed = AttributedString()
            while let c = contentIterator.next() {
                if c.lowercased() == query.first?.lowercased() {
                    query.removeFirst()
                    var _attributed = AttributedString(String(c))
                    _attributed.inlinePresentationIntent = .stronglyEmphasized
                    attributed += _attributed
                } else {
                    if attributed.runs.isEmpty {
                        if self.mustIncludeFirstKeyword && isFirst {
                            return nil
                        }
                        // does not match at all
                        return __recursiveMatch(_query: query, components: components.dropFirst()).map { AttributedString(content) + $0 }
                    }
                    var cx = String(c)
                    while let next = contentIterator.next() { cx.append(next) }
                    attributed += AttributedString(cx)
                    break
                }
            }
            
            return __recursiveMatch(_query: query, components: components.dropFirst()).map({ attributed + $0 }) ?? (isFirst && self.mustIncludeFirstKeyword ? nil : __recursiveMatch(_query: _query, components: components.dropFirst()).map({ AttributedString(content) + $0 }))
        }
    }
    
    
    // MARK: - File Operations
    
    func reveal(query: String) {
        self.openedRecords[query, default: 0] += 1
        withErrorPresented {
            let path = self.item
            try path.reveal()
            Task { @MainActor in
                NSApp.hide(nil)
                ModelProvider.instance.searchText = ""
            }
            
            Task.detached {
                try ModelProvider.instance.save()
            }
        }
    }
    
    func open(query: String) {
        self.openedRecords[query, default: 0] += 1
        let item = self.item
        let openableFileRelativePath = self.openableFileRelativePath
        Task {
            await withErrorPresented {
                let path = item.appending(path: openableFileRelativePath)
                try await path.open()
                Task { @MainActor in
                    NSApp.hide(nil)
                    ModelProvider.instance.searchText = ""
                }
                
                Task.detached {
                    try ModelProvider.instance.save()
                }
            }
        }
    }
}
