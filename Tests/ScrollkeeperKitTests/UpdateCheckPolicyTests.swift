import Foundation
@testable import ScrollkeeperKit
import Testing

@Suite struct UpdateCheckPolicyTests {
    private let policy = UpdateCheckPolicy.standard
    private let now = Date(timeIntervalSince1970: 1_800_000_000)
    private let day = UpdateCheckPolicy.day

    private func old(_ packageID: String) -> CheckCandidate {
        CheckCandidate(packageID: packageID, lastActivity: now.addingTimeInterval(-3 * 365 * day))
    }

    private func recent(_ packageID: String) -> CheckCandidate {
        CheckCandidate(packageID: packageID, lastActivity: now.addingTimeInterval(-30 * day))
    }

    private func candidates(_ count: Int) -> [CheckCandidate] {
        (0..<count).map { old(String(format: "pkg-%04d", $0)) }
    }

    private func log(checked: [String: TimeInterval] = [:], listedDaysAgo: Double? = nil) -> UpdateCheckLog {
        var log = UpdateCheckLog()
        log.lastChecked = checked.mapValues { now.addingTimeInterval(-$0 * day) }
        log.lastListing = listedDaysAgo.map { now.addingTimeInterval(-$0 * day) }
        return log
    }

    @Test func aSmallLibraryIsCheckedInFull() {
        let plan = policy.backgroundPlan(for: candidates(3), log: UpdateCheckLog(), now: now)
        #expect(plan == .lookups(["pkg-0000", "pkg-0001", "pkg-0002"]))
    }

    @Test func anEditionCheckedWithinTheLastDayIsLeftAlone() {
        let checked = log(checked: ["pkg-0000": 0.5, "pkg-0001": 1.5])
        let plan = policy.backgroundPlan(for: candidates(2), log: checked, now: now)
        #expect(plan == .lookups(["pkg-0001"]))
        #expect(policy.checkable(["pkg-0000", "pkg-0001", "new"], log: checked, now: now) == ["pkg-0001", "new"])
    }

    @Test func aListingCountsAsACheckOfEveryEdition() {
        let listedToday = log(listedDaysAgo: 0.2)
        #expect(policy.backgroundPlan(for: candidates(5), log: listedToday, now: now) == .lookups([]))
        #expect(listedToday.latest == now.addingTimeInterval(-0.2 * day))

        let listedLastWeek = log(listedDaysAgo: 7)
        #expect(policy.backgroundPlan(for: candidates(2), log: listedLastWeek, now: now)
            == .lookups(["pkg-0000", "pkg-0001"]))
    }

    @Test func theDailyAllowanceCapsALargerLibrary() {
        let many = candidates(60)
        guard case let .lookups(first) = policy.backgroundPlan(for: many, log: UpdateCheckLog(), now: now) else {
            Issue.record("expected lookups")
            return
        }
        #expect(first.count == policy.dailyLookups)

        // Once those are logged, the allowance is spent until a day has passed.
        var spent = UpdateCheckLog()
        spent.lastChecked = Dictionary(uniqueKeysWithValues: first.map { ($0, now) })
        let later = now.addingTimeInterval(day / 2)
        #expect(policy.backgroundPlan(for: many, log: spent, now: later) == .lookups([]))

        // The next day the editions never checked go first.
        let nextDay = now.addingTimeInterval(day + 60)
        guard case let .lookups(second) = policy.backgroundPlan(for: many, log: spent, now: nextDay) else {
            Issue.record("expected lookups")
            return
        }
        #expect(second.count == policy.dailyLookups)
        #expect(Set(second.prefix(10)) == Set(many.map(\.packageID)).subtracting(first))
    }

    @Test func lookupsOnViewCountTowardTheAllowance() {
        var used = UpdateCheckLog()
        used.lastChecked = Dictionary(uniqueKeysWithValues: (0..<48).map { ("viewed-\($0)", now) })
        guard case let .lookups(planned) = policy.backgroundPlan(for: candidates(10), log: used, now: now) else {
            Issue.record("expected lookups")
            return
        }
        #expect(planned.count == 2)
    }

    @Test func recentEditionsAreDueMoreOftenThanOlderOnes() {
        var tight = policy
        tight.dailyLookups = 1
        // Eight days is more than one interval for a recent edition; twenty is less than one for an old one.
        let checked = log(checked: ["new-book": 8, "old-book": 20])
        let plan = tight.backgroundPlan(for: [old("old-book"), recent("new-book")], log: checked, now: now)
        #expect(plan == .lookups(["new-book"]))

        let longAgo = log(checked: ["new-book": 8, "old-book": 45])
        #expect(tight.backgroundPlan(for: [old("old-book"), recent("new-book")], log: longAgo, now: now)
            == .lookups(["old-book"]))
    }

    @Test func aFullyDownloadedLibraryIsListedOnceAMonthInstead() {
        let everything = candidates(policy.listingThreshold + 1)
        #expect(policy.backgroundPlan(for: everything, log: UpdateCheckLog(), now: now) == .listing)
        #expect(policy.backgroundPlan(for: everything, log: log(listedDaysAgo: 10), now: now) == .lookups([]))
        #expect(policy.backgroundPlan(for: everything, log: log(listedDaysAgo: 31), now: now) == .listing)

        let justUnder = candidates(policy.listingThreshold)
        guard case let .lookups(planned) = policy.backgroundPlan(for: justUnder, log: UpdateCheckLog(), now: now) else {
            Issue.record("expected lookups")
            return
        }
        #expect(planned.count == policy.dailyLookups)
    }

    @Test func theLogKnowsItsLatestCheck() {
        #expect(UpdateCheckLog().latest == nil)
        #expect(log(checked: ["a": 3, "b": 1], listedDaysAgo: 9).latest == now.addingTimeInterval(-day))
    }
}

@Suite struct FileStatusTests {
    private let paizo = FakePaizo()
    private let updated = "Tue Jul 21 2026 20:35:38 GMT+0000 (Coordinated Universal Time)"

    private func makeClient() -> LibraryCatalogClient {
        paizo.installSignedInStore()
        let session = PaizoSession(http: paizo.http, credentials: MemoryCredentialStore(FakePaizo.account))
        return LibraryCatalogClient(http: paizo.http, session: session)
    }

    @Test func fileStatusCarriesTheUpdateDateAndTheCurrentFile() async throws {
        paizo.installFileStatus(updated: ["core": updated, "map": ""])
        let client = makeClient()

        let core = try await client.fetchFileStatus(packageID: "core")
        #expect(core.dateUpdated == Date(timeIntervalSince1970: 1_784_666_138))
        #expect(core.fileName == "book-v2.pdf")
        #expect(core.filePath == "https://bucket.example/book-v2.pdf")
        #expect(try await client.fetchFileStatus(packageID: "map").dateUpdated == nil)
        #expect(paizo.http.requestLines.contains(
            "GET https://app.paizo.com/api/library/entitlement/customer/core?token=\(FakePaizo.token)"
        ))
    }

    @Test func anUnknownEditionIsAnErrorAfterOneRetry() async {
        paizo.installFileStatus(updated: [:])
        let client = makeClient()

        await #expect(throws: PaizoError.http(operation: "Checking gone for an update", status: 500)) {
            try await client.fetchFileStatus(packageID: "gone")
        }
        #expect(paizo.http.count(of: "/api/library/entitlement/customer/gone") == 2)
    }

    @Test func anAnswerWithoutAPackageIsUnexpected() async {
        paizo.http.on("GET https://app.paizo.com/api/library/entitlement/customer/", json: ["data": ["x": 1]])
        let client = makeClient()

        await #expect(throws: PaizoError.unexpectedResponse(operation: "Checking odd for an update")) {
            try await client.fetchFileStatus(packageID: "odd")
        }
    }

    @Test func fetchingStopsAtTheFirstFailure() async {
        paizo.installFileStatus(updated: ["a": "", "b": "", "d": "", "e": "", "f": "", "g": ""])
        let fetcher = FileStatusFetcher(client: makeClient(), concurrentLookups: 2)

        let learned = await fetcher.fetch(["a", "b", "c", "d", "e", "f", "g"])

        #expect(Set(learned.map(\.packageID)).isSuperset(of: ["a", "b"]))
        #expect(!learned.map(\.packageID).contains("c"))
        #expect(paizo.http.count(of: "/customer/g?") == 0)
    }

    @Test func fetchingNothingAsksNothing() async {
        let fetcher = FileStatusFetcher(client: makeClient(), concurrentLookups: 2)
        #expect(await fetcher.fetch([]).isEmpty)
        #expect(paizo.http.requests.isEmpty)
    }

    @Test func aCheckKeepsWhatPaizoLeavesOut() {
        var entitlement = Fixtures.entitlement("Core Rules PDF")
        let known = Date(timeIntervalSince1970: 1_700_000_000)
        entitlement.dateUpdated = known

        entitlement.apply(FileStatus(packageID: entitlement.packageID, dateUpdated: nil, fileName: "", filePath: ""))
        #expect(entitlement.dateUpdated == known)
        #expect(entitlement.fileName == "book.pdf")

        let newer = known.addingTimeInterval(1000)
        entitlement.apply(FileStatus(packageID: entitlement.packageID, dateUpdated: newer, fileName: "v2.pdf",
                                     filePath: "https://bucket.example/v2.pdf"))
        #expect(entitlement.dateUpdated == newer)
        #expect(entitlement.fileName == "v2.pdf")
    }
}
