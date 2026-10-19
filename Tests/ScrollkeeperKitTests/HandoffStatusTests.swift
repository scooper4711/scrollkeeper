import Foundation
@testable import ScrollkeeperKit
import Testing

/// The links that tell an app how its request is going.
@Suite struct HandoffStatusTests {
    @Test(arguments: [
        (HandoffStatus.downloading(0.4271), "pluck://handoff?sku=PZO1&state=downloading&fraction=0.43"),
        (.failed("No account"), "pluck://handoff?sku=PZO1&state=failed&reason=No%20account"),
        (.done, "pluck://handoff?sku=PZO1&state=done")
    ])
    func becomesALinkInTheAppsScheme(status: HandoffStatus, expected: String) {
        #expect(status.url(for: .pluck, sku: "PZO1")?.absoluteString == expected)
    }

    @Test func usesEachAppsOwnScheme() {
        #expect(HandoffStatus.done.url(for: .mapsmith, sku: "PZO1")?.absoluteString
            == "mapsmith://handoff?sku=PZO1&state=done")
    }

    @Test func throttlesProgressToWholePercents() {
        var throttle = HandoffStatusThrottle()
        let sent = [HandoffStatus.downloading(0), .downloading(0.004), .downloading(0.011), .downloading(0.011),
                    .done, .done, .failed("x")].filter { throttle.shouldSend($0) }
        #expect(sent == [.downloading(0), .downloading(0.011), .done, .failed("x")])
    }
}

@MainActor
@Suite struct StoreHandoffStatusTests {
    private let harness = StoreHarness(records: [
        Fixtures.record(id: "pdf", name: "Pathfinder Adventure: Cradle PDF", sku: "CRADLE", file: "cradle.pdf")
    ])

    @Test func reportsTheDownloadARequestWaitsFor() async throws {
        let store = await harness.makeSyncedStore()
        let request = HandoffRequest(sku: "CRADLE", app: .pluck)
        #expect(store.handoffStatus(for: request) == nil)

        let item = try #require(store.item(id: "CRADLE"))
        let target = try #require(store.handoffTarget(for: item))
        store.downloads[target.id] = .waiting
        #expect(store.handoffStatus(for: request) == .downloading(0))
        store.downloads[target.id] = .inProgress(0.5)
        #expect(store.handoffStatus(for: request) == .downloading(0.5))
        store.downloads[target.id] = .failed("x")
        #expect(store.handoffStatus(for: request) == nil)
        #expect(store.handoffStatus(for: HandoffRequest(sku: "NOPE", app: .pluck)) == nil)
    }
}
