//
//  QueryItemProtocol.swift
//  SpotFile
//
//  Created by Vaida on 2024/2/28.
//

import Essentials
import SwiftUI
import SwiftData
import UndoTracking
import FinderItem


protocol QueryItemProtocol: AnyObject, UndoTracking {
    
    var id: UUID { get }
    
    var query: Query { get }
    
    var item: FinderItem { get }
    
    var openableFileRelativePath: String { get }
    
    var iconSystemName: String { get }
    
    func updateRecords(_ query: String, context: ModelContext)
    
    func match(query: String) -> QueryItem.Match?
    
    func matches(lowercasedQueryChars: [Character]) -> Bool
    
    func match(lowercasedQueryChars: [Character]) -> QueryItem.Match?
    
}


extension QueryItemProtocol {
    
    
    // MARK: - Handling matches
    
    func match(query: String) -> QueryItem.Match? {
        if let match = self.query.match(query: query, isChild: self is QueryItemChild) {
            return QueryItem.Match(text: match, isPrimary: true)
        }
        
        return nil
    }
    
    func matches(lowercasedQueryChars: [Character]) -> Bool {
        self.query.matches(lowercasedQueryChars: lowercasedQueryChars, isChild: self is QueryItemChild)
    }
    
    func match(lowercasedQueryChars: [Character]) -> QueryItem.Match? {
        if let match = self.query.match(lowercasedQueryChars: lowercasedQueryChars, isChild: self is QueryItemChild) {
            return QueryItem.Match(text: match, isPrimary: true)
        }
        
        return nil
    }
    
    
    // MARK: - File Operations
    
    func reveal(query: String, context: ModelContext) {
        updateRecords(query, context: context)
        withErrorPresented("Cannot open reveal file") {
            let path = self.item
            Task { @MainActor in
                try await path.reveal()
                
                try postSubmitAction()
            }
        }
    }
    
    func open(query: String, context: ModelContext) async {
        updateRecords(query, context: context)
        let item = self.item
        
        await withErrorPresented("Cannot open the file") {
            let path: FinderItem
            
            if let child = self as? QueryItemChild {
                let _item = child.queryItem
                
                if let relativePath = _item.childOptions.relativePath,
                   let match = try? item.children(range: .enumeration).first(where: {(try? relativePath.wholeMatch(in: $0.relativePath(to: item)!)) != nil }) {
                    path = match
                } else {
                    path = item
                }
            } else {
                // child doesn't have a `relative path`. As already reflected in `item`.
                let openableFileRelativePath = self.openableFileRelativePath
                path = item.appending(path: openableFileRelativePath)
            }
            
            try await path.open()
            try await postSubmitAction()
        }
    }
}


private let emphasizedAttributeContainer = {
    var container = AttributeContainer()
    container.inlinePresentationIntent = .stronglyEmphasized
    return container
}()

@MainActor
func postSubmitAction() throws {
    NSApp.hide(nil)
    ModelProvider.instance.searchText = ""
    ModelProvider.instance.reset()
    
    try ModelProvider.instance.save()
}
