//
//  TextFieldView.swift
//  SpotFile
//
//  Created by Vaida on 2024/2/18.
//

import Foundation
import AppKit
import SwiftUI

// original code from https://developer.apple.com/library/archive/samplecode/CustomMenus

struct SuggestionTextField: NSViewRepresentable {
    
    let modelProvider: ModelProvider
    
    
    func makeNSView(context: Context) -> NSSearchField {
        let searchField = NSSearchField(frame: .zero)
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
        return Coordinator(modelProvider: modelProvider)
    }
    
    final class Coordinator: NSObject, NSSearchFieldDelegate {
        
        let modelProvider: ModelProvider
        
        
        init(modelProvider: ModelProvider) {
            self.modelProvider = modelProvider
        }
        
        var searchField: NSSearchField!
        
        // MARK: - NSSearchField Delegate Methods
        
        @objc func controlTextDidChange(_ notification: Notification) {
            let text = self.searchField.stringValue
            if text.isEmpty {
                modelProvider.previous.reset()
                modelProvider.reset()
                modelProvider.matches.removeAll()
            }
            modelProvider.searchText = text
        }
        
        @objc func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
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
                commandSelector == #selector(NSResponder.cancelOperation(_:)) {
                modelProvider.searchText = ""
                
                return true
            } else if commandSelector == #selector(NSResponder.insertNewline(_:)) {
                modelProvider.submitItem()
                
                return true
            } else {
                return false
            }
        }
    }
}
