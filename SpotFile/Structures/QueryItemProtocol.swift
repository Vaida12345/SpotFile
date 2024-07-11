//
//  QueryItemProtocol.swift
//  SpotFile
//
//  Created by Vaida on 2024/2/28.
//


import SwiftUI
import Stratum
import ViewCollection


protocol QueryItemProtocol: AnyObject, UndoTracking {
    
    var id: UUID { get }
    
    var query: Query { get }
    
    var item: FinderItem { get }
    
    var openableFileRelativePath: String { get }
    
    var iconSystemName: String { get }
    
    var openedRecords: [String: Int] { get set }
    
}


extension QueryItemProtocol {
    
    func updateRecords(_ query: String) {
        self.openedRecords[query, default: 0] += 1
    }
    
    
    // MARK: - Handling matches
    
    func match(query: String) -> QueryItem.Match? {
        if let match = self.query.match(query: query, isChild: self is QueryItemChild) {
            return QueryItem.Match(text: match, isPrimary: true)
        }
        
        return nil
    }
    
    
    // MARK: - File Operations
    
    func reveal(query: String) {
        updateRecords(query)
        withErrorPresented("Cannot open reveal file") {
            let path = self.item
            Task { @MainActor in
                try path.reveal()
                Task {
                    postSubmitAction()
                }
            }
        }
    }
    
    func open(query: String) {
        updateRecords(query)
        let item = self.item
        let openableFileRelativePath = self.openableFileRelativePath
        Task {
            await withErrorPresented("Cannot open the file") {
                let path: FinderItem
                
                if self is QueryItem {
                    path = item.appending(path: openableFileRelativePath)
                } else {
                    let _item = (self as! QueryItemChild).queryItem
                    if item.appending(path: _item.childOptions.relativePath).exists {
                        path = item.appending(path: _item.childOptions.relativePath)
                    } else {
                        path = item
                    }
                }
                try await path.open()
                postSubmitAction()
            }
        }
    }
}


private let emphasizedAttributeContainer = {
    var container = AttributeContainer()
    container.inlinePresentationIntent = .stronglyEmphasized
    return container
}()

func postSubmitAction() {
    Task { @MainActor in
        NSApp.hide(nil)
        ModelProvider.instance.searchText = ""
    }
    
    Task.detached {
        try ModelProvider.instance.save()
    }
}
