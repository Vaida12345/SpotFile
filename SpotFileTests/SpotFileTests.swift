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
        let item = QueryItem(query: "swift structum", item: .desktopDirectory, openableFileRelativePath: "")
        print(item.queryComponents)
        print(item.match(query: "structum")?.description ?? "nil")
    }

}
