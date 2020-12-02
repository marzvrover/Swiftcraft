import XCTest

import SwiftcraftTests
import SwiftcraftLibraryTests

var tests = [XCTestCaseEntry]()
tests += SwiftcraftTests.allTests()
tests += SwiftcraftLibraryTests.allTests()
XCTMain(tests)
