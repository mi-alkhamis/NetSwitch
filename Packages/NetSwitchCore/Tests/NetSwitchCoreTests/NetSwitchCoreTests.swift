import XCTest
@testable import NetSwitchCore

final class NetSwitchCoreTests: XCTestCase {
    func testStaticProfileRequiresCompleteConfiguration() {
        let profile = Profile(name: "Office", useDHCP: false, ipAddress: "10.0.1.50")
        XCTAssertThrowsError(try ProfileValidator.validate(profile))
    }

    func testStorePersistsAndFindsCaseInsensitively() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let store = try ProfileStore(fileURL: directory.appendingPathComponent("profiles.json"))
        try store.add(Profile(name: "Home", dnsServers: ["1.1.1.1"]))
        XCTAssertEqual(store.find(name: "home")?.dnsServers, ["1.1.1.1"])
    }
}
