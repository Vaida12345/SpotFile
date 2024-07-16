//
//  TextFieldView.swift
//  SpotFile
//
//  Created by Vaida on 2024/2/18.
//

import Foundation
import AppKit
import SwiftUI
import SwiftData


// original code from https://developer.apple.com/library/archive/samplecode/CustomMenus

struct SuggestionTextField: NSViewRepresentable {
    
    let modelProvider: ModelProvider
    
    let context: ModelContext
    
    
    func makeNSView(context: Context) -> NSSearchField {
        let searchField = NSSearchField(frame: .zero)
        searchField.maximumRecents = 0
        searchField.controlSize = .regular
        searchField.font = NSFont.systemFont(ofSize: NSFont.systemFontSize(for: searchField.controlSize))
        searchField.setContentCompressionResistancePriority(NSLayoutConstraint.Priority(rawValue: 1), for: .horizontal)
        searchField.setContentHuggingPriority(NSLayoutConstraint.Priority(rawValue: 1), for: .horizontal)
        searchField.delegate = context.coordinator
        
        let searchFieldCell = searchField.cell!
        searchFieldCell.lineBreakMode = .byWordWrapping
        
        context.coordinator.searchField = searchField
        
        return searchField
    }
    
    @MainActor
    func updateNSView(_ searchField: NSSearchField, context: Context) {
        if let prefix = modelProvider.previous.parentQuery,
            modelProvider.searchText.hasPrefix(prefix) {
            let pendingUpdate = String(modelProvider.searchText.dropFirst(prefix.count))
            if searchField.stringValue != pendingUpdate {
                searchField.stringValue = pendingUpdate
            }
        } else {
            if searchField.stringValue != modelProvider.searchText {
                searchField.stringValue = modelProvider.searchText
            }
        }
    }
    
    func makeCoordinator() -> Coordinator {
        return Coordinator(modelProvider: modelProvider, context: context)
    }
    
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
            modelProvider.submitItem(context: context)
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
                modelProvider.submitItem(context: context)
                
                return true
            } else {
                return false
            }
        }
    }
}
