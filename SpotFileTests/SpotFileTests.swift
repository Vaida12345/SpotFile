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
        print(item.queryComponents)
        let date = Date()
        print(item.match(query: "maths readings")?.description ?? "nil")
        print(date.distanceToNow())
    }

}
