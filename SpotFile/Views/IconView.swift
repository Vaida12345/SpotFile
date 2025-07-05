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
    @Environment(\.colorScheme) private var colorScheme
    
    
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
                        .imageScale(.large)
                }
            } else {
                AsyncView(generator: makePreview) { container in
                    switch container {
                    case .cgImage(let cgImage): AsyncDrawnImage(cgImage: cgImage, frame: .square(scale.side))
                    case .system(let name, let color):
                        Image(systemName: name)
                            .imageScale(.large)
                            .foregroundStyle(isSelected ? .white : color) // safe to modify color
                    case .custom(let name, let color):
                        Image(name)
                            .imageScale(.large)
                            .foregroundStyle(isSelected ? .white : color)
                    }
                }
                .id(finderItem)
            }
        }
        .frame(width: scale.side, height: scale.side)
    }
    
    private nonisolated func makePreview() async -> ImageContainer? {
        let item = await finderItem
        
        if item.extension == "swift" {
            return .system("swift", Color(red: 219 / 255, green: 84 / 255, blue: 56 / 255))
        } else if item.name == "Package.swift" {
            return .system("shippingbox", Color(red: 219 / 255, green: 84 / 255, blue: 56 / 255))
        } else if (item/"Package.swift").exists {
            return .system("shippingbox", Color(red: 219 / 255, green: 84 / 255, blue: 56 / 255))
        } else if (item/"\(item.name).xcodeproj").exists {
            return .custom("xcodeproj", Color(red: 51 / 255, green: 97 / 255, blue: 216 / 255))
        }
        
        guard let contentType = try? item.contentType else { return nil }
        
        if contentType.conforms(to: .text) {
            return .system("text.justify.left", .primary)
        }
        
        guard let cgImage = try? await item.load(.preview(size: .square(scale.side * displayScale))).cgImage else { return nil }
        return .cgImage(cgImage)
    }
    
    
    enum ImageContainer {
        case system(String, Color)
        case custom(String, Color)
        case cgImage(CGImage)
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
