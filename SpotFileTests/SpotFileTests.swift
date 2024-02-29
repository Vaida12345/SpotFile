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

    func testQueryItem1() throws {
        let item = QueryItem(query: "Study/Maths/Materials/Readings/Teaching Secondary School Mathematics", item: .desktopDirectory, openableFileRelativePath: "")
        
        measure {
            _ = item.match(query: "maths readings")
        }   
    }
    
    func testQueryItem2() throws {
        let item = QueryItem(query: "Study/Maths/Materials/Readings/Teaching Secondary School Mathematics", item: .desktopDirectory, openableFileRelativePath: "")
        
        var options = XCTMeasureOptions()
        options.iterationCount = 1000
        
        measure(options: options) {
            _ = item.match(query: "Study/Maths/Materials/Readings/Teaching Secondary School Mathematics")
        }
    }
    
    func testQueryItem3() throws {
        let item = QueryItem(query: "Study/Maths/Materials/Readings/Teaching Secondary School Mathematics", item: .desktopDirectory, openableFileRelativePath: "")
        
        var options = XCTMeasureOptions()
        options.iterationCount = 1000
        
        measure(options: options) {
            _ = item.match(query: "Study/Maths/Materials/Readings/Teaching Secondary School Mathematicse")
        }
    }

}
