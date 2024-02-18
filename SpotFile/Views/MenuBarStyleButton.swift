//
//  MenuBarStyleButton.swift
//  SpotFile
//
//  Created by Vaida on 2024/2/4.
//

import SwiftUI
import ViewCollection

struct MenuBarStyleButton<Label>: View where Label: View {
    
    let keyboardShortcut: Text?
    
    let action: () -> Void
    
    let label: () -> Label
    
    @State private var isOnHover = false
    
    var body: some View {
        Button {
            action()
        } label: {
            HStack {
                label()
                    .modifier(enabled: isOnHover) { contentView in
                        contentView
                            .foregroundStyle(.white)
                    } else: { contentView in
                        contentView
                            .foregroundStyle(.primary)
                    }
                
                Spacer()
                
                if let keyboardShortcut {
                    HStack {
                        keyboardShortcut
                            .modifier(enabled: isOnHover) { contentView in
                                contentView
                                    .foregroundStyle(.white)
                            } else: { contentView in
                                contentView
                                    .foregroundStyle(.tertiary)
                            }
                        
                        Spacer()
                    }
                    .frame(width: 35)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.vertical, 5)
        .padding(.leading, 7)
        .frame(maxWidth: .infinity)
        .frame(height: 25)
        .background(isOnHover ? Color.accentColor : .clear)
        .onHover { hovering in
            self.isOnHover = hovering
        }
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .fontWeight(.regular)
    }
    
    init(keyboardShortcut: Text? = nil, action: @escaping () -> Void,  @ViewBuilder label: @escaping () -> Label) {
        self.keyboardShortcut = keyboardShortcut
        self.action = action
        self.label = label
    }
}

#Preview {
    MenuBarStyleButton(keyboardShortcut: Text(Image(systemName: "command")) + Text(" R")) {
        
    } label: {
        HStack {
            Text("Settings...")
            Spacer()
        }
    }
    .frame(width: 200)
}
