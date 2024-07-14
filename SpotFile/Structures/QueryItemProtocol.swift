//
//  QueryItemProtocol.swift
//  SpotFile
//
//  Created by Vaida on 2024/2/28.
//


import SwiftUI
import Stratum
import ViewCollection
import SwiftData


protocol QueryItemProtocol: AnyObject, UndoTracking {
    
    var id: UUID { get }
    
    var query: Query { get }
    
    var item: FinderItem { get }
    
    var openableFileRelativePath: String { get }
    
    var iconSystemName: String { get }
    
    func updateRecords(_ query: String, context: ModelContext)
    
}


extension QueryItemProtocol {
    
    
    // MARK: - Handling matches
    
    func match(query: String) -> QueryItem.Match? {
        if let match = self.query.match(query: query, isChild: self is QueryItemChild) {
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
                try path.reveal()
                
                try postSubmitAction()
            }
        }
    }
    
    func open(query: String, context: ModelContext) {
        updateRecords(query, context: context)
        let item = self.item
        let openableFileRelativePath = self.openableFileRelativePath
        withErrorPresented("Cannot open the file") {
            let path: FinderItem
            
            if let child = self as? QueryItemChild {
                let _item = child.queryItem
                if item.appending(path: _item.childOptions.relativePath).exists {
                    path = item.appending(path: _item.childOptions.relativePath)
                } else {
                    path = item
                }
            } else {
                path = item.appending(path: openableFileRelativePath)
            }
            
            Task {
                try await path.open()
                try await postSubmitAction()
            }
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
    
    try ModelProvider.instance.save()
}
