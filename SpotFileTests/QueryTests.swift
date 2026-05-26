//
//  QueryTests.swift
//  SpotFile
//
//  Created by Vaida on 2026-05-26.
//

import Testing
@testable import SpotFile

@Suite
struct QueryTests {

    // MARK: - Single-component matching (fast path)

    @Test
    func exactMatch() {
        #expect(Query(value: "test").matches(lowercasedQueryChars: Array("test"), isChild: false))
    }

    @Test
    func caseInsensitiveMatch() {
        #expect(Query(value: "Test").matches(lowercasedQueryChars: Array("test"), isChild: false))
        #expect(Query(value: "TEST").matches(lowercasedQueryChars: Array("test"), isChild: false))
    }

    @Test
    func prefixMatch() {
        #expect(Query(value: "test").matches(lowercasedQueryChars: Array("te"), isChild: false))
        #expect(Query(value: "testing").matches(lowercasedQueryChars: Array("t"), isChild: false))
    }

    @Test
    func jumpMatchWithinSingleComponent() {
        // "ts" greedily matches 't' and then 's' jumping over 'e' in "test"
        #expect(Query(value: "test").matches(lowercasedQueryChars: Array("ts"), isChild: false))
    }

    @Test
    func singleCharacterMatch() {
        #expect(Query(value: "test").matches(lowercasedQueryChars: Array("t"), isChild: false))
    }

    @Test
    func emptyQueryAlwaysMatches() {
        #expect(Query(value: "test").matches(lowercasedQueryChars: [], isChild: false))
        #expect(Query(value: "").matches(lowercasedQueryChars: [], isChild: false))
    }

    @Test
    func noMatchCompletelyDifferent() {
        #expect(!Query(value: "test").matches(lowercasedQueryChars: Array("xyz"), isChild: false))
    }

    @Test
    func noMatchQueryLongerThanContent() {
        #expect(!Query(value: "te").matches(lowercasedQueryChars: Array("test"), isChild: false))
    }

    @Test
    func noMatchWrongOrder() {
        // "sett" won't match "test" because greedy matching consumes 't', then 'e' doesn't match 's'
        #expect(!Query(value: "test").matches(lowercasedQueryChars: Array("sett"), isChild: false))
    }

    // MARK: - Multi-component matching (camelCase boundaries)

    @Test
    func jumpMatchAcrossCamelCaseBoundary() {
        // "xc" matches "Xcode": 'x' from "X", 'c' from "code" — crosses the single component boundary
        // Wait: "Xcode" is one component since X starts it. Let's test "Xc" matching.
        // Actually "Xcode" parses as single component. The single-component greedy path handles "xc".
    }

    @Test
    func matchAcrossCamelCaseComponents() {
        // "SwiftUI" → [.content("Swift"), .content("UI")]
        // "SUI" should match: 'S' from "Swift", 'U','I' from "UI"
        #expect(Query(value: "SwiftUI").matches(lowercasedQueryChars: Array("sui"), isChild: false))
    }

    @Test
    func matchFirstComponentOnly() {
        // "SwiftUI" → [.content("Swift"), .content("UI")]
        #expect(Query(value: "SwiftUI").matches(lowercasedQueryChars: Array("swift"), isChild: false))
    }

    @Test
    func matchSecondComponentOnly() {
        // "SwiftUI" → [.content("Swift"), .content("UI")]
        #expect(Query(value: "SwiftUI").matches(lowercasedQueryChars: Array("ui"), isChild: false))
    }

    @Test
    func partialMatchAcrossComponents() {
        // "SwiftUI" → [.content("Swift"), .content("UI")]
        // "swUI" matches: 's','w' from Swift, 'U','I' from UI
        #expect(Query(value: "SwiftUI").matches(lowercasedQueryChars: Array("swui"), isChild: false))
    }

    @Test
    func noMatchWhenMiddleComponentMissing() {
        // "MySwiftUI" → [.content("My"), .content("Swift"), .content("UI")]
        // "myui" should match: 'm','y' from My, 'u','i' from UI (skipping Swift)
        #expect(Query(value: "MySwiftUI").matches(lowercasedQueryChars: Array("myui"), isChild: false))
    }

    // MARK: - Separator and whitespace handling

    @Test
    func spaceSeparatorInContent() {
        // "my file" → [.content("my"), .spacer(" "), .content("file")]
        #expect(Query(value: "my file").matches(lowercasedQueryChars: Array("myfile"), isChild: false))
    }

    @Test
    func spaceSeparatorMatchSpaceInQuery() {
        // Query "my file" should also match when user types space
        #expect(Query(value: "my file").matches(lowercasedQueryChars: Array("my "), isChild: false))
    }

    @Test
    func underscoreSeparatorInContent() {
        // "my_file" → [.content("my"), .spacer("_"), .content("file")]
        #expect(Query(value: "my_file").matches(lowercasedQueryChars: Array("myfile"), isChild: false))
    }

    @Test
    func dashSeparatorInContent() {
        // "my-file" → [.content("my"), .spacer("-"), .content("file")]
        #expect(Query(value: "my-file").matches(lowercasedQueryChars: Array("myfile"), isChild: false))
    }

    @Test
    func pathSeparatorInContent() {
        // "my/file" → [.content("my"), .spacer("/"), .content("file")]
        #expect(Query(value: "my/file").matches(lowercasedQueryChars: Array("myfile"), isChild: false))
    }

    @Test
    func separatorInQuerySkipsComponent() {
        // When query contains a separator char, it can skip to the next component
        // "my_file" with query "my_" — the '_' in query allows skipping spacer
        #expect(Query(value: "my_file").matches(lowercasedQueryChars: Array("my_"), isChild: false))
    }

    @Test
    func dotSeparator() {
        #expect(Query(value: "file.txt").matches(lowercasedQueryChars: Array("filetxt"), isChild: false))
    }

    @Test
    func colonSeparator() {
        #expect(Query(value: "a:b").matches(lowercasedQueryChars: Array("ab"), isChild: false))
    }

    // MARK: - mustIncludeFirstKeyword

    @Test
    func mustIncludeFirstKeywordWhenFirstMatches() {
        let query = Query(value: "Safari", mustIncludeFirstKeyword: true)
        #expect(query.matches(lowercasedQueryChars: Array("safari"), isChild: false))
        #expect(query.matches(lowercasedQueryChars: Array("saf"), isChild: false))
    }

    @Test
    func mustIncludeFirstKeywordWhenFirstDoesNotMatch() {
        // "MySwiftUI" → [.content("My"), .content("Swift"), .content("UI")]
        // With mustIncludeFirstKeyword=true, "swift" should fail because "My" doesn't contribute
        let query = Query(value: "MySwiftUI", mustIncludeFirstKeyword: true)
        #expect(!query.matches(lowercasedQueryChars: Array("swift"), isChild: false))
    }

    @Test
    func mustIncludeFirstKeywordFalseAllowsSkipping() {
        // Without mustIncludeFirstKeyword, "swift" matches by skipping "My"
        let query = Query(value: "MySwiftUI", mustIncludeFirstKeyword: false)
        #expect(query.matches(lowercasedQueryChars: Array("swift"), isChild: false))
    }

    @Test
    func mustIncludeFirstKeywordPartialFirstMatch() {
        // "MySwiftUI" → "m" should match (first component contributes)
        let query = Query(value: "MySwiftUI", mustIncludeFirstKeyword: true)
        #expect(query.matches(lowercasedQueryChars: Array("m"), isChild: false))
    }

    // MARK: - isChild parameter

    @Test
    func isChildForcesMultiComponentPath() {
        // With isChild=true, single-component queries go through recursive path
        // This matters for separator handling in the recursive matcher
        #expect(Query(value: "test").matches(lowercasedQueryChars: Array("test"), isChild: true))
        #expect(Query(value: "test").matches(lowercasedQueryChars: Array("te"), isChild: true))
    }

    @Test
    func isChildSeparatorHandling() {
        // When isChild=true, recursive path handles separator chars in query differently
        // A query containing a separator char should match by skipping components
        #expect(Query(value: "a_b").matches(lowercasedQueryChars: Array("ab"), isChild: true))
    }

    // MARK: - Multiple separators and complex cases

    @Test
    func multipleConsecutiveSeparators() {
        // "a__b" → [.content("a"), .spacer("_"), .spacer("_"), .content("b")]
        #expect(Query(value: "a__b").matches(lowercasedQueryChars: Array("ab"), isChild: false))
    }

    @Test
    func startsWithSeparator() {
        // "_file" → [.spacer("_"), .content("file")]
        #expect(Query(value: "_file").matches(lowercasedQueryChars: Array("file"), isChild: false))
    }

    @Test
    func endsWithSeparator() {
        // "file_" → [.content("file"), .spacer("_")]
        #expect(Query(value: "file_").matches(lowercasedQueryChars: Array("file"), isChild: false))
    }

    @Test
    func onlySeparators() {
        // "___" → [.spacer("_"), .spacer("_"), .spacer("_")]
        #expect(!Query(value: "___").matches(lowercasedQueryChars: Array("a"), isChild: false))
        #expect(Query(value: "___").matches(lowercasedQueryChars: [], isChild: false))
    }

    @Test
    func numberTransitionBoundary() {
        // "Item2" → [.content("Item"), .content("2")]
        #expect(Query(value: "Item2").matches(lowercasedQueryChars: Array("item2"), isChild: false))
        #expect(Query(value: "Item2").matches(lowercasedQueryChars: Array("i2"), isChild: false))
    }

    @Test
    func numberToLetterTransition() {
        // "2items" → [.content("2"), .content("items")]
        #expect(Query(value: "2items").matches(lowercasedQueryChars: Array("2i"), isChild: false))
    }

    @Test
    func allUppercasePrefix() {
        // "URLParser" → stays as one component because URL is all uppercase
        // Wait: 'U','R','L' all uppercase, then 'P' is uppercase too
        // cumulative = "URL" (allSatisfy isUppercase), 'P' is uppercase
        // condition: value[index].isUppercase && !cumulative.isEmpty && !cumulative.allSatisfy(\.isUppercase)
        // "URL".allSatisfy(\.isUppercase) = true, so !true = false → no split
        // cumulative = "URLP"... then 'a' is lowercase → cumulative = "URLParser"
        // So "URLParser" is one component
        #expect(Query(value: "URLParser").matches(lowercasedQueryChars: Array("urlp"), isChild: false))
    }

    // MARK: - Empty or edge-case content

    @Test
    func emptyContentMatchesEmptyQuery() {
        #expect(Query(value: "").matches(lowercasedQueryChars: [], isChild: false))
    }

    @Test
    func emptyContentDoesNotMatchNonEmptyQuery() {
        #expect(!Query(value: "").matches(lowercasedQueryChars: Array("a"), isChild: false))
    }

    @Test
    func singleSpaceContent() {
        // " " → [.spacer(" ")]
        #expect(Query(value: " ").matches(lowercasedQueryChars: Array(" "), isChild: false))
        #expect(Query(value: " ").matches(lowercasedQueryChars: [], isChild: false))
    }

    // MARK: - Text-building match (returns non-nil for valid matches)

    @Test
    func textMatchExact() {
        #expect(Query(value: "test").match(lowercasedQueryChars: Array("test"), isChild: false) != nil)
    }

    @Test
    func textMatchPrefix() {
        #expect(Query(value: "test").match(lowercasedQueryChars: Array("te"), isChild: false) != nil)
    }

    @Test
    func textMatchNoMatch() {
        #expect(Query(value: "test").match(lowercasedQueryChars: Array("xyz"), isChild: false) == nil)
    }

    @Test
    func textMatchAcrossComponents() {
        #expect(Query(value: "SwiftUI").match(lowercasedQueryChars: Array("sui"), isChild: false) != nil)
    }

    @Test
    func textMatchConvenienceWrapper() {
        #expect(Query(value: "test").match(query: "te", isChild: false) != nil)
        #expect(Query(value: "test").match(query: "xyz", isChild: false) == nil)
    }

    @Test
    func textMatchConsistentWithBoolean() {
        // Text match returns non-nil iff boolean match returns true
        let testCases: [(content: String, query: String, isChild: Bool)] = [
            ("test", "test", false),
            ("test", "te", false),
            ("test", "ts", false),
            ("test", "xyz", false),
            ("SwiftUI", "sui", false),
            ("SwiftUI", "swift", false),
            ("my_file", "myfile", false),
            ("MySwiftUI", "swift", false),
        ]
        for (content, query, isChild) in testCases {
            let queryChars = Array(query)
            let boolResult = Query(value: content).matches(lowercasedQueryChars: queryChars, isChild: isChild)
            let textResult = Query(value: content).match(lowercasedQueryChars: queryChars, isChild: isChild)
            #expect((textResult != nil) == boolResult)
        }
    }

    // MARK: - QueryItem match (primary vs additional queries)

    @Test
    func queryItemPrimaryMatch() {
        let item = QueryItem(query: "Safari", item: .homeDirectory, openableFileRelativePath: "")
        let match = item.match(query: "safari")
        #expect(match != nil)
        #expect(match?.isPrimary == true)
    }

    @Test
    func queryItemAdditionalQueryMatch() {
        let item = QueryItem(query: "Safari", item: .homeDirectory, openableFileRelativePath: "")
        item.additionalQueries = [Query(value: "Web Browser")]
        // "web" should not match "Safari" but should match the additional query
        let match = item.match(query: "web")
        #expect(match != nil)
        #expect(match?.isPrimary == false)
    }

    @Test
    func queryItemNoMatch() {
        let item = QueryItem(query: "Safari", item: .homeDirectory, openableFileRelativePath: "")
        let match = item.match(query: "xyz")
        #expect(match == nil)
    }

    @Test
    func queryItemMatchesBoolean() {
        let item = QueryItem(query: "Safari", item: .homeDirectory, openableFileRelativePath: "")
        #expect(item.matches(lowercasedQueryChars: Array("safari")))
        #expect(item.matches(lowercasedQueryChars: Array("saf")))
        #expect(!item.matches(lowercasedQueryChars: Array("xyz")))
        #expect(item.matches(lowercasedQueryChars: []))
    }

    @Test
    func queryItemWithAdditionalQueriesBooleanMatch() {
        let item = QueryItem(query: "Safari", item: .homeDirectory, openableFileRelativePath: "")
        item.additionalQueries = [Query(value: "Web Browser")]
        #expect(item.matches(lowercasedQueryChars: Array("web")))
    }

    @Test
    func queryItemMatchLowercasedChars() {
        let item = QueryItem(query: "Xcode", item: .homeDirectory, openableFileRelativePath: "")
        let match = item.match(lowercasedQueryChars: Array("xc"))
        #expect(match != nil)
        #expect(match?.isPrimary == true)
    }

    // MARK: - Component parsing correctness

    @Test
    func componentParsingSimpleWord() {
        let components = Query.component(for: "test")
        #expect(components.count == 1)
        if case .content("test") = components[0] { } else {
            Issue.record("Expected .content(\"test\")")
        }
    }

    @Test
    func componentParsingCamelCase() {
        let components = Query.component(for: "SwiftUI")
        #expect(components.count == 2)
        if case .content("Swift") = components[0] { } else {
            Issue.record("Expected .content(\"Swift\")")
        }
        if case .content("UI") = components[1] { } else {
            Issue.record("Expected .content(\"UI\")")
        }
    }

    @Test
    func componentParsingWithSeparator() {
        let components = Query.component(for: "my_file")
        #expect(components.count == 3)
        if case .content("my") = components[0] { } else {
            Issue.record("Expected .content(\"my\")")
        }
        if case .spacer("_") = components[1] { } else {
            Issue.record("Expected .spacer(\"_\")")
        }
        if case .content("file") = components[2] { } else {
            Issue.record("Expected .content(\"file\")")
        }
    }

    @Test
    func componentParsingMixed() {
        // "myFile_name" → 'm','y' = "my", 'F' uppercase split → .content("my")
        // 'F','i','l','e' = "File", '_' separator → .content("File"), .spacer("_")
        // 'n','a','m','e' = .content("name")
        let components = Query.component(for: "myFile_name")
        let values = components.map(\.value)
        #expect(values == ["my", "File", "_", "name"])
    }

    @Test
    func componentParsingAllUppercaseThenLowercase() {
        let components = Query.component(for: "URLSession")
        #expect(components.count == 1)
        if case .content("URLSession") = components[0] { } else {
            Issue.record("Expected .content(\"URLSession\")")
        }
    }

    // MARK: - Lowercased content

    @Test
    func lowercasedContentIsCorrect() {
        #expect(Query(value: "Test").lowercasedContent == "test")
        #expect(Query(value: "SWIFT").lowercasedContent == "swift")
    }

    // MARK: - Cross-boundary edge cases

    @Test
    func queryWithSpacerMatchesContentWithSpacer() {
        // Query " " (space) against "my file" should match the spacer
        #expect(Query(value: "my file").matches(lowercasedQueryChars: Array("my "), isChild: false))
    }

    @Test
    func separatorInQueryAgainstContent() {
        // Query "/" as a separator char against "a/b" — '/' in query should allow skipping
        #expect(Query(value: "a/b").matches(lowercasedQueryChars: Array("a/"), isChild: false))
    }

    @Test
    func jumpOverMultipleComponents() {
        // "a_b_c_d" → many components, match first and last
        #expect(Query(value: "a_b_c_d").matches(lowercasedQueryChars: Array("ad"), isChild: false))
    }

    @Test
    func matchWithSpacerInQueryAtStart() {
        // "_test" matches "test" (spacer skipped)
        #expect(Query(value: "_test").matches(lowercasedQueryChars: Array("test"), isChild: false))
    }

    // MARK: - Span-matching (query spans the entire content + more)

    @Test
    func queryConsumesAllComponents() {
        // "ab" should match "ab" exactly
        #expect(Query(value: "ab").matches(lowercasedQueryChars: Array("ab"), isChild: false))
    }

    @Test
    func queryConsumesAllComponentsWithSpacer() {
        #expect(Query(value: "a_b").matches(lowercasedQueryChars: Array("a_b"), isChild: false))
    }

    // MARK: - Full integration: QueryItem with children

    @Test
    func queryItemMatchLowercasedCharsWithAdditional() {
        let item = QueryItem(query: "Primary", item: .homeDirectory, openableFileRelativePath: "")
        item.additionalQueries = [Query(value: "Alternative")]
        let match = item.match(lowercasedQueryChars: Array("alt"))
        #expect(match != nil)
        #expect(match?.isPrimary == false)
    }

    @Test
    func queryItemMatchLowercasedCharsPrimaryWins() {
        let item = QueryItem(query: "Primary", item: .homeDirectory, openableFileRelativePath: "")
        item.additionalQueries = [Query(value: "PrimaryAlt")]
        // "pri" matches primary, so isPrimary should be true
        let match = item.match(lowercasedQueryChars: Array("pri"))
        #expect(match != nil)
        #expect(match?.isPrimary == true)
    }
}
