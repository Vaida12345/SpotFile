//
//  IconView.swift
//  SpotFile
//
//  Created by Vaida on 7/11/24.
//

import SwiftUI
import FinderItem
import ViewCollection


struct IconView: View {
    
    let item: any QueryItemProtocol
    
    let scale: Scale
    
    let isSelected: Bool
    
    var finderItem: FinderItem {
        item.item
    }
    
    @Environment(\.displayScale) private var displayScale
    
    
    var body: some View {
        Group {
            if !item.iconSystemName.isEmpty {
                if item.iconSystemName == "xcodeproj" {
                    Image(.xcodeproj)
                        .imageScale(.large)
                        .foregroundStyle(isSelected ? .white : Color(red: 51 / 255, green: 97 / 255, blue: 216 / 255))
                } else if item.iconSystemName == "xcodeproj.fill" {
                    Image(.xcodeprojFill)
                        .imageScale(.large)
                        .foregroundStyle(isSelected ? .white : Color(red: 51 / 255, green: 97 / 255, blue: 216 / 255))
                } else {
                    Image(systemName: item.iconSystemName)
                }
            } else {
                AsyncDrawnImage(generator: makePreview, frame: .square(scale.side))
                    .id(finderItem)
            }
        }
        .frame(width: scale.side, height: scale.side)
    }
    
    
    private nonisolated func systemImage(_ name: String, tint: NSColor) -> CGImage? {
        let configuration = NSImage.SymbolConfiguration(pointSize: 64, weight: .regular, scale: .medium)
        return NSImage(systemSymbolName: name, accessibilityDescription: nil)?
            .withSymbolConfiguration(configuration)?
            .tint(color: tint).cgImage
    }
    
    private nonisolated func makePreview() async -> CGImage? {
        let item = await finderItem
        
        if item.extension == "swift" {
            return systemImage("swift", tint: NSColor(red: 219 / 255, green: 84 / 255, blue: 56 / 255, alpha: 1))
        } else if item.name == "Package.swift" {
            return systemImage("shippingbox", tint: NSColor(red: 219 / 255, green: 84 / 255, blue: 56 / 255, alpha: 1))
        } else if (item/"Package.swift").exists {
            return systemImage("shippingbox", tint: NSColor(red: 219 / 255, green: 84 / 255, blue: 56 / 255, alpha: 1))
        } else if (item/"\(item.name).xcodeproj").exists {
            return NSImage(symbolName: "xcodeproj", variableValue: 0)?.tint(color: .white).cgImage
        }
        
        guard let contentType = try? item.contentType else { return nil }
        
        if contentType.conforms(to: .text) {
            return systemImage("text.justify.left", tint: .white)
        }
        
        return try? await item.load(.preview(size: .square(scale.side * displayScale))).cgImage
    }
    
    
    enum Scale {
        case small
        case large
        
        var side: CGFloat {
            switch self {
            case .small:
                20
            case .large:
                50
            }
        }
    }
}


extension NSImage {
    func tint(color: NSColor) -> NSImage {
        NSImage(size: size, flipped: false) { rect in
            color.set()
            rect.fill()
            self.draw(in: rect, from: NSRect(origin: .zero, size: self.size), operation: .destinationIn, fraction: 1.0)
            return true
        }
    }
}
