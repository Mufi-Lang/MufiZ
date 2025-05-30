import XCTest
import SwiftTreeSitter
import TreeSitterMufiz

final class TreeSitterMufizTests: XCTestCase {
    func testCanLoadGrammar() throws {
        let parser = Parser()
        let language = Language(language: tree_sitter_mufiz())
        XCTAssertNoThrow(try parser.setLanguage(language),
                         "Error loading MufiZ grammar")
    }
}
