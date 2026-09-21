//
//  TextFIeld + Coordinator.swift
//  SpotFile
//
//  Created by Vaida on 2025-07-05.
//

import AppKit
import SwiftData
import Combine


extension SuggestionTextField {
    
    final class Coordinator: NSObject, NSSearchFieldDelegate {
        
        let modelProvider: ModelProvider
        let context: ModelContext
        
        let fileSearcher: FileSearcher
        
        var cancellables: Set<AnyCancellable> = []
        
        init(modelProvider: ModelProvider, context: ModelContext) {
            self.modelProvider = modelProvider
            self.context = context
            
            self.fileSearcher = FileSearcher()
            super.init()
            
            self.fileSearcher.createPublisher(context: context)
                .receive(on: RunLoop.main)
                .sink { result in
                    MainActor.assumeIsolated {
                        guard result.request.text == modelProvider.searchText, result.request.parent?.id == modelProvider.deepSearchTarget?.id else {
                            return  // this is from an old result, ignore.
                        }
                        
                        if result.options.contains(.reset) {
                            modelProvider.reset()
                        } else {
                            switch result.match {
                            case .direct(let matches):
                                modelProvider.matches = matches.enumerated().map { ($0.0, $0.1.0, $0.1.1) }
                                modelProvider.deepSearchTarget = nil
                                
                            case .deep(let target, let parentQuery, let matches):
                                modelProvider.matches = matches.enumerated().map { ($0.0, $0.1.0, $0.1.1) }
                                if modelProvider.deepSearchTarget == nil, let parentQuery, modelProvider.searchText.lowercased().hasPrefix(parentQuery) {
                                    modelProvider.searchText.removeFirst(parentQuery.count)
                                }
                                modelProvider.deepSearchTarget = target
                                
                            case .goto(let goto, let match):
                                modelProvider.matches = [(0, goto, match)]
                                modelProvider.deepSearchTarget = nil
                                
                            default:
                                break
                            }
                        }
                    }
                }
                .store(in: &cancellables)
            
            self.fileSearcher.isSearching
                .receive(on: RunLoop.main)
                .sink { newValue in
                    MainActor.assumeIsolated {
                        modelProvider.isSearching = newValue
                    }
                }
                .store(in: &cancellables)
        }
        
        var searchField: NSSearchField!
        
        // MARK: - NSSearchField Delegate Methods
        
        func controlTextDidChange(_ notification: Notification) {
            let text = self.searchField.stringValue
            
            modelProvider.searchText = text
            fileSearcher.sendSearchRequest(text, parent: modelProvider.deepSearchTarget)
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
                fileSearcher.reset()
                
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
                    modelProvider.deepSearchTarget = item
                    fileSearcher.sendSearchRequest(" ", parent: item)
                }
                
                return true
            } else {
                return false
            }
        }
    }
    
}
