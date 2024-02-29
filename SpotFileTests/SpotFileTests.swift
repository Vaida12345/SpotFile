//
//  SpotFileTests.swift
//  SpotFileTests
//
//  Created by Vaida on 2024/2/17.
//

import XCTest
@testable
import SpotFile

final class SpotFileTests: XCTestCase {

    func testQueryItem() throws {
        let item = QueryItem(query: "Study/Maths/Materials/Readings/Teaching Secondary School Mathematics", item: .desktopDirectory, openableFileRelativePath: "")
        
        let date = Date()
        print(item.match(query: "maths readings")?.description ?? "nil")
        print(date.distanceToNow())
        
//        var attributeContainer = AttributeContainer()
//        attributeContainer.inlinePresentationIntent = .stronglyEmphasized
//        
//        let date = Date()
//        
//        var attributed = AttributedString("a1234", attributes: attributeContainer)
//        print(date.distanceToNow())
            
    }

}
