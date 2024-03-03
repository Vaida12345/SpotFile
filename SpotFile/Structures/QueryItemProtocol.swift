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
    
    
    /// the returned components are NOT lowercased
    var queryComponents: [QueryComponent] { get }
    
    func updateRecords(_ query: String)
    
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
    
    
    func match(query: String) -> Text? {
        let queryComponents = self.queryComponents
        let query = Array(query.lowercased()) // use array, as array is `RandomAccessCollection`.
        
        return __recursiveMatch(_query: query[query.startIndex...], components: queryComponents[0...], isFirst: true)
    }
    
    private func __recursiveMatch(_query: ArraySlice<Character>, components: ArraySlice<QueryComponent>, isFirst: Bool = false) -> Text? {
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
    
    
    // MARK: - File Operations
    
    func reveal(query: String) {
        updateRecords(query)
        withErrorPresented {
            let path = item
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
        updateRecords(query)
        let item = self.item
        let openableFileRelativePath = self.openableFileRelativePath
        Task {
            await withErrorPresented {
                let path = if self is QueryItem {
                    item.appending(path: openableFileRelativePath)
                } else {
                    item
                }
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


private let emphasizedAttributeContainer = {
    var container = AttributeContainer()
    container.inlinePresentationIntent = .stronglyEmphasized
    return container
}()
