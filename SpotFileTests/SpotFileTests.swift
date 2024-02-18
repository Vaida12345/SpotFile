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
        let item = QueryItem(query: "swift testRoom", item: .desktopDirectory, openableFileRelativePath: "")
        print(item.queryComponents)
//        print(item.match(query: "swift"))
//        print(item.match(query: "swift test"))
//        print(item.match(query: "test"))
//        print(item.match(query: "swift test room"))
//        print(item.match(query: "str")) // FIXME: deal with false positive
//        print(item.match(query: "abc"))
    }

}
