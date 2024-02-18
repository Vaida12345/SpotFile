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
        if searchField.stringValue != modelProvider.searchText {
            searchField.stringValue = modelProvider.searchText
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
            modelProvider.searchText = text
        }
        
        @objc func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            if commandSelector == #selector(NSResponder.moveUp(_:)) {
                if modelProvider.selectionIndex > 0 {
                    modelProvider.selectionIndex -= 1
                    return true
                }
                return false
            }
            
            if commandSelector == #selector(NSResponder.moveDown(_:)) {
                if modelProvider.selectionIndex < modelProvider.matches.count - 1 {
                    modelProvider.selectionIndex += 1
                    return true
                }
                return false
            }
            
            if commandSelector == #selector(NSResponder.complete(_:)) ||
                commandSelector == #selector(NSResponder.cancelOperation(_:)) {
                modelProvider.searchText = ""
                
                return true
            }
            
            if commandSelector == #selector(NSResponder.insertNewline(_:)) {
                modelProvider.submitItem()
                
                return true
            }
            
            return false
        }
    }
}
