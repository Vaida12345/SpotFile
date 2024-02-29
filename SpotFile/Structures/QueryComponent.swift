//
//  QueryComponent.swift
//  SpotFile
//
//  Created by Vaida on 2024/2/28.
//

import Foundation


enum QueryComponent: Codable {
    
    /// Spacer should **always** be `Character`
    case spacer(String)
    
    case content(String)
    
    
    var value: String {
        switch self {
        case .spacer(let string):
            return string
        case .content(let string):
            return string
        }
    }
    
}
