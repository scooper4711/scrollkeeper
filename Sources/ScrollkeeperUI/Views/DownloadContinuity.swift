import ScrollkeeperKit
import SwiftUI

#if !os(macOS)
import UIKit
#endif

/// Keeps downloads going across the app leaving and returning to the front.
///
/// iPadOS suspends an app soon after the user switches away, which cuts its downloads off.
/// Leaving with downloads under way asks the system for extra time, which lets short ones finish;
/// coming back resumes the ones that were cut off.
@MainActor
enum DownloadContinuity {
    static func sceneChanged(to phase: ScenePhase, store: LibraryStore) {
        switch phase {
        case .active:
            endExtraTime()
            store.resumeInterruptedDownloads()
        case .background:
            if store.pendingDownloadCount > 0 {
                beginExtraTime()
            }
        default:
            break
        }
    }

    /// Extra time is handed back as soon as the last download is done.
    static func pendingChanged(to pending: Int) {
        if pending == 0 {
            endExtraTime()
        }
    }

    #if os(macOS)
    private static func beginExtraTime() {
        // A Mac app keeps running in the background; there is nothing to ask for.
    }

    private static func endExtraTime() {
        // See beginExtraTime.
    }
    #else
    private static var extraTime = UIBackgroundTaskIdentifier.invalid

    private static func beginExtraTime() {
        guard extraTime == .invalid else { return }
        extraTime = UIApplication.shared.beginBackgroundTask(withName: "Finishing downloads") {
            // The system's allowance has run out; give the time back before the app is suspended.
            Task { @MainActor in endExtraTime() }
        }
    }

    private static func endExtraTime() {
        guard extraTime != .invalid else { return }
        UIApplication.shared.endBackgroundTask(extraTime)
        extraTime = .invalid
    }
    #endif
}
