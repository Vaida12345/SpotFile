//
//  MenuBarStyleButton.swift
//  SpotFile
//
//  Created by Vaida on 2024/2/4.
//

import SwiftUI


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
                    .foregroundStyle(isOnHover ? .white : .primary)
                
                Spacer()
                
                if let keyboardShortcut {
                    HStack {
                        keyboardShortcut
                            .foregroundStyle(isOnHover ? AnyShapeStyle(.white) : AnyShapeStyle(.tertiary))
                        
                        Spacer()
                    }
                    .frame(width: 40)
                }
            }
            .padding(.vertical, 5)
            .padding(.leading, 7)
            .frame(maxWidth: .infinity)
            .frame(height: 25)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(isOnHover ? Color.accentColor : .clear)
        .onHover { hovering in
            self.isOnHover = hovering
        }
        .clipShape(RoundedRectangle(cornerRadius: 10))
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
