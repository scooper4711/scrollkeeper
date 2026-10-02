import Foundation

/// When each edition was last checked for an update.
public struct UpdateCheckLog: Codable, Sendable, Equatable {
    /// The time of the last single lookup, by package identifier.
    public var lastChecked: [String: Date] = [:]
    /// When the whole library was last listed, which checks every edition at once.
    public var lastListing: Date?

    public init() {}

    /// The most recent check of any kind, or nil when there has been none.
    public var latest: Date? {
        (lastChecked.values + [lastListing].compactMap { $0 }).max()
    }

    /// When the edition was last checked, by a lookup or by a listing; nil when never.
    func lastCheck(of packageID: String) -> Date? {
        [lastChecked[packageID], lastListing].compactMap { $0 }.max()
    }

    func lookupCount(since start: Date) -> Int {
        lastChecked.values.filter { $0 > start }.count
    }
}

/// A downloaded edition as the policy sees it.
public struct CheckCandidate: Sendable, Equatable {
    public var packageID: String
    /// The latest of its release, its last update and the day it joined the library.
    public var lastActivity: Date

    public init(packageID: String, lastActivity: Date) {
        self.packageID = packageID
        self.lastActivity = lastActivity
    }
}

/// What a background check should do.
public enum UpdateCheckPlan: Equatable, Sendable {
    /// Ask about these editions one by one. May be empty.
    case lookups([String])
    /// List the whole library again.
    case listing
}

/// Decides which downloaded editions to ask Paizo about, so that the load stays the same
/// however much of the library has been downloaded.
public struct UpdateCheckPolicy: Sendable, Equatable {
    static let day: TimeInterval = 24 * 60 * 60

    /// Lookups allowed in any 24 hours.
    public var dailyLookups = 50
    /// Lookups in flight at once.
    public var concurrentLookups = 2
    /// An edition is not asked about more often than this.
    public var minimumInterval = day
    /// How often a recent edition is due.
    public var recentInterval = 7 * day
    /// How often any other edition is due.
    public var olderInterval = 30 * day
    /// An edition is recent when its last activity is at most this long ago.
    public var recentAge = 365 * day
    /// With more downloaded editions than this, listing the library costs Paizo less than
    /// asking about each: about 900 lookups of a second against 61 pages of fifteen.
    public var listingThreshold = 900
    /// Time between the full syncs made in place of lookups.
    public var listingInterval = 30 * day
    /// Pages fetched at once in such a sync.
    public var listingConcurrentPages = 2

    public init() {}

    public static let standard = UpdateCheckPolicy()

    /// The plan for a check nobody is waiting for: the most overdue editions that fit in what is
    /// left of the day's allowance, or a listing when there are too many to ask about singly.
    public func backgroundPlan(for candidates: [CheckCandidate], log: UpdateCheckLog, now: Date) -> UpdateCheckPlan {
        if candidates.count > listingThreshold {
            return isListingDue(log, now: now) ? .listing : .lookups([])
        }
        let allowance = max(0, dailyLookups - log.lookupCount(since: now.addingTimeInterval(-Self.day)))
        let ranked = candidates
            .filter { isCheckable($0.packageID, log: log, now: now) }
            .map { (packageID: $0.packageID, overdue: overdue($0, log: log, now: now)) }
            .sorted { ($0.overdue, $1.packageID) > ($1.overdue, $0.packageID) }
        return .lookups(ranked.prefix(allowance).map(\.packageID))
    }

    /// The editions among `packageIDs` that have not been checked within the minimum interval.
    public func checkable(_ packageIDs: [String], log: UpdateCheckLog, now: Date) -> [String] {
        packageIDs.filter { isCheckable($0, log: log, now: now) }
    }

    private func isCheckable(_ packageID: String, log: UpdateCheckLog, now: Date) -> Bool {
        guard let last = log.lastCheck(of: packageID) else { return true }
        return now.timeIntervalSince(last) >= minimumInterval
    }

    private func isListingDue(_ log: UpdateCheckLog, now: Date) -> Bool {
        guard let last = log.lastListing else { return true }
        return now.timeIntervalSince(last) >= listingInterval
    }

    /// How long ago the edition was checked, measured in its own interval. Never checked ranks first.
    private func overdue(_ candidate: CheckCandidate, log: UpdateCheckLog, now: Date) -> Double {
        guard let last = log.lastCheck(of: candidate.packageID) else { return .infinity }
        let isRecent = now.timeIntervalSince(candidate.lastActivity) <= recentAge
        return now.timeIntervalSince(last) / (isRecent ? recentInterval : olderInterval)
    }
}
