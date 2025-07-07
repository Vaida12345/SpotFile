//
//  TextFIeld + Coordinator.swift
//  SpotFile
//
//  Created by Vaida on 2025-07-05.
//

import AppKit
import SwiftData


extension SuggestionTextField {
    
    final class Coordinator: NSObject, NSSearchFieldDelegate {
        
        let modelProvider: ModelProvider
        
        let context: ModelContext
        
        
        init(modelProvider: ModelProvider, context: ModelContext) {
            self.modelProvider = modelProvider
            self.context = context
        }
        
        var searchField: NSSearchField!
        
        // MARK: - NSSearchField Delegate Methods
        
        func controlTextDidChange(_ notification: Notification) {
            let text = self.searchField.stringValue
            
            if text.isEmpty {
                modelProvider.reset()
            } else {
                modelProvider.searchText = text
                modelProvider.updateSearches(context: context)
            }
        }
        
        func controlTextDidEndEditing(_ obj: Notification) {
            Task {
                await modelProvider.submitItem(context: context)
            }
        }
        
        func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            if commandSelector == #selector(NSResponder.moveUp(_:)) {
                if modelProvider.selectionIndex > 0 {
                    modelProvider.selectionIndex -= 1
                    if modelProvider.selectionIndex - modelProvider.shownStartIndex < 0 {
                        modelProvider.shownStartIndex -= 1
                    }
                }
                return true // always consume
            } else if commandSelector == #selector(NSResponder.moveDown(_:)) {
                if modelProvider.selectionIndex < modelProvider.matches.count - 1 {
                    modelProvider.selectionIndex += 1
                    if modelProvider.selectionIndex - modelProvider.shownStartIndex >= 25 {
                        modelProvider.shownStartIndex += 1
                    }
                    
                }
                return true // always consume
            } else if commandSelector == #selector(NSResponder.complete(_:)) ||
                        commandSelector == #selector(NSResponder.cancelOperation(_:)) ||
                        commandSelector == #selector(NSResponder.deleteToBeginningOfLine(_:)) {
                modelProvider.reset()
                
                return true
            } else if commandSelector == #selector(NSResponder.insertNewline(_:)) {
                Task {
                    await modelProvider.submitItem(context: context)
                }
                
                return true
            } else if commandSelector == #selector(NSResponder.insertTab(_:)), modelProvider.selectionIndex < modelProvider.matches.count {
                let selection = modelProvider.matches[modelProvider.selectionIndex]
                if let item = selection.1 as? QueryItem {
                    modelProvider.searchText = " "
                    modelProvider.updateSearches(context: context, forceDeepSearch: item)
                }
                
                return true
            } else {
                return false
            }
        }
    }
    
}
