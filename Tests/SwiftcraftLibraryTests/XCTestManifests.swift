import XCTest

#if !canImport(ObjectiveC)
public func allTests() -> [XCTestCaseEntry] {
    return [
        testCase(DataTypeTests.allTests),
        testCase(PacketCodecTests.allTests),
    ]
}
#endif
