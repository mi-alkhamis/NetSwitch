import XCTest
@testable import NetSwitchCore

final class NetSwitchCoreTests: XCTestCase {

    // MARK: - Validation

    func testStaticProfileRequiresCompleteConfiguration() {
        let profile = Profile(name: "Office", useDHCP: false, ipAddress: "10.0.1.50")
        XCTAssertThrowsError(try ProfileValidator.validate(profile))
    }

    // MARK: - Shell quoting (injection regression)

    // These are the tests that matter most: the quoted string is handed to `do shell script … with
    // administrator privileges`, so anything that survives quoting runs as root.

    func testShellQuotingNeutralizesExpansion() {
        XCTAssertEqual(NetworkClient.shellQuoted("Wi-Fi$(whoami)"), "'Wi-Fi$(whoami)'")
        XCTAssertEqual(NetworkClient.shellQuoted("Wi-Fi`id`"), "'Wi-Fi`id`'")
        XCTAssertEqual(NetworkClient.shellQuoted("$HOME"), "'$HOME'")
        XCTAssertEqual(NetworkClient.shellQuoted("back\\slash"), "'back\\slash'")
        XCTAssertEqual(NetworkClient.shellQuoted("quo\"te"), "'quo\"te'")
        XCTAssertEqual(NetworkClient.shellQuoted("semi;colon && pipe|"), "'semi;colon && pipe|'")
    }

    func testShellQuotingEscapesEmbeddedSingleQuote() {
        // The one character single quotes cannot contain: close, emit an escaped quote, reopen.
        XCTAssertEqual(NetworkClient.shellQuoted("single'quote"), "'single'\\''quote'")
        XCTAssertEqual(NetworkClient.shellQuoted("'; rm -rf /"), "''\\''; rm -rf /'")
    }

    func testShellCommandQuotesEachArgumentIndependently() {
        XCTAssertEqual(
            NetworkClient.shellCommand(["/usr/sbin/networksetup", "-setdhcp", "Wi-Fi 2"]),
            "'/usr/sbin/networksetup' '-setdhcp' 'Wi-Fi 2'"
        )
    }

    // MARK: - Output inspection

    // networksetup exits 0 even when it fails, so its output is the only failure signal.

    func testNetworksetupErrorPrefixIsAFailure() {
        XCTAssertEqual(
            NetworkClient.reportedFailure(in: "** Error: The parameters were not valid."),
            "** Error: The parameters were not valid."
        )
    }

    func testAuthorizationFailureIsAFailure() {
        XCTAssertNotNil(NetworkClient.reportedFailure(in: "AuthorizationCreate() failed: -60008"))
    }

    func testEmptyDNSResponseIsNotAFailure() {
        // networksetup's way of saying "no DNS configured". `info(for:)` reads this as an empty
        // DNS list, so treating it as an error would break every status refresh.
        XCTAssertNil(NetworkClient.reportedFailure(in: "There aren't any DNS Servers set on Wi-Fi."))
    }

    func testOrdinaryOutputIsNotAFailure() {
        XCTAssertNil(NetworkClient.reportedFailure(in: "1.1.1.1\n8.8.8.8"))
        XCTAssertNil(NetworkClient.reportedFailure(in: ""))
        XCTAssertNil(NetworkClient.reportedFailure(in: "Wi-Fi\nEthernet\nThunderbolt Bridge"))
    }

    func testCancelledAuthorizationIsRecognized() {
        XCTAssertTrue(NetworkClient.wasCancelled("execution error: User canceled. (-128)"))
    }

    func testOtherFailuresAreNotMistakenForCancellation() {
        XCTAssertFalse(NetworkClient.wasCancelled("** Error: The parameters were not valid."))
        XCTAssertFalse(NetworkClient.wasCancelled("AuthorizationCreate() failed: -60008"))
    }

    // MARK: - DNS arguments

    func testEmptyDNSListUsesNetworksetupClearKeyword() throws {
        XCTAssertEqual(
            try NetworkClient.dnsArguments([], for: "Wi-Fi"),
            ["-setdnsservers", "Wi-Fi", "Empty"]
        )
    }

    func testDNSServersArePassedThroughInOrder() throws {
        XCTAssertEqual(
            try NetworkClient.dnsArguments(["1.1.1.1", "8.8.8.8"], for: "Wi-Fi"),
            ["-setdnsservers", "Wi-Fi", "1.1.1.1", "8.8.8.8"]
        )
    }

    func testNonAddressDNSServerIsRejected() {
        XCTAssertThrowsError(try NetworkClient.dnsArguments(["$(whoami)"], for: "Wi-Fi"))
        XCTAssertThrowsError(try NetworkClient.dnsArguments(["not-an-ip"], for: "Wi-Fi"))
    }

    // MARK: - Errors

    func testUnknownServiceErrorNamesWhatIsAvailable() {
        let message = NetworkClientError.unknownService("Wi-Fi 2", ["Wi-Fi", "Ethernet"])
            .localizedDescription
        XCTAssertTrue(message.contains("Wi-Fi 2"), message)
        XCTAssertTrue(message.contains("Ethernet"), message)
    }

    // MARK: - ProfileStore

    /// A fresh directory per test, removed in teardown so runs can't see each other's files.
    private var scratch: URL!

    override func setUpWithError() throws {
        scratch = FileManager.default.temporaryDirectory
            .appendingPathComponent("NetSwitchCoreTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: scratch, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let scratch {
            try? FileManager.default.removeItem(at: scratch)
        }
        scratch = nil
    }

    private func storeURL() -> URL {
        scratch.appendingPathComponent("profiles.json")
    }

    private func makeStore() throws -> ProfileStore {
        try ProfileStore(fileURL: storeURL())
    }

    func testStorePersistsAndFindsCaseInsensitively() throws {
        let store = try makeStore()
        try store.add(Profile(name: "Home", dnsServers: ["1.1.1.1"]))
        XCTAssertEqual(store.find(name: "home")?.dnsServers, ["1.1.1.1"])
    }

    func testStoreRoundTripsThroughDisk() throws {
        let fileURL = storeURL()
        let store = try ProfileStore(fileURL: fileURL)
        try store.add(
            Profile(
                name: "Office",
                service: "Ethernet",
                useDHCP: false,
                ipAddress: "10.0.1.50",
                subnetMask: "255.255.255.0",
                gateway: "10.0.1.1",
                dnsServers: ["9.9.9.9"]
            )
        )

        let reopened = try ProfileStore(fileURL: fileURL)
        XCTAssertEqual(reopened.profiles, store.profiles)
        XCTAssertEqual(reopened.profiles.first?.service, "Ethernet")
    }

    func testDeleteByIDRemovesOnlyTheTargetedProfile() throws {
        let store = try makeStore()
        let home = Profile(name: "Home", dnsServers: ["1.1.1.1"])
        let homeOffice = Profile(name: "Home Office", dnsServers: ["8.8.8.8"])
        try store.add(home)
        try store.add(homeOffice)

        try store.delete(id: homeOffice.id)

        XCTAssertEqual(store.profiles.map(\.id), [home.id])
    }

    func testDeleteByIDRejectsAnUnknownIdentifier() throws {
        let store = try makeStore()
        try store.add(Profile(name: "Home"))
        XCTAssertThrowsError(try store.delete(id: UUID()))
        XCTAssertEqual(store.profiles.count, 1)
    }

    func testDeleteByNameStillWorksForTheCLI() throws {
        let store = try makeStore()
        try store.add(Profile(name: "Home"))
        try store.add(Profile(name: "Office"))

        try store.delete(name: "home")

        XCTAssertEqual(store.profiles.map(\.name), ["Office"])
    }

    func testDuplicateNamesAreRejectedOnAdd() throws {
        let store = try makeStore()
        try store.add(Profile(name: "Home"))
        XCTAssertThrowsError(try store.add(Profile(name: "home")))
    }

    func testDuplicateNamesAreRejectedOnUpdate() throws {
        let store = try makeStore()
        try store.add(Profile(name: "Home"))
        var office = Profile(name: "Office")
        try store.add(office)

        office.name = "HOME"

        XCTAssertThrowsError(try store.update(office))
    }

    func testInMemoryStoreKeepsProfilesWithoutPersisting() throws {
        let store = ProfileStore.inMemory()
        XCTAssertFalse(store.isPersistent)

        try store.add(Profile(name: "Home"))
        try store.load() // A no-op for this store; must not wipe the in-memory list.

        XCTAssertEqual(store.profiles.map(\.name), ["Home"])
    }
}
