import XCTest
@testable import SharedKit

final class SharedKitTests: XCTestCase {
    func testPrettyName() {
        XCTAssertFalse(AppInfo.prettyName().isEmpty)
    }
}
