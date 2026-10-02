import Foundation

extension LibraryStore {
    public func isDownloaded(_ target: DownloadTarget) -> Bool {
        locator.isDownloaded(target)
    }

    /// True when Paizo has updated the file since this copy was downloaded.
    public func isOutdated(_ target: DownloadTarget) -> Bool {
        locator.isOutdated(target)
    }

    /// The downloaded file, or the unpacked files of an archive. Empty when not downloaded.
    public func files(in target: DownloadTarget) -> [URL] {
        locator.files(in: target)
    }

    /// At most this many downloads run at once, to go easy on Paizo's servers; the rest wait.
    public static let maximumConcurrentDownloads = 5

    /// The downloads that are running, waiting or have failed, oldest first.
    public var downloadJobs: [DownloadJob] {
        downloadOrder.compactMap { target in
            downloads[target.id].map { DownloadJob(target: target, state: $0) }
        }
    }

    /// Downloads the file unless it is already on its way. When five downloads are running it
    /// waits for its turn. The zip of a PDF edition is unpacked into its folder and then removed.
    public func download(_ target: DownloadTarget) {
        if downloads[target.id]?.isPending == true {
            return
        }
        downloadOrder.removeAll { $0.id == target.id }
        downloadOrder.append(target)
        if downloadTasks.count < Self.maximumConcurrentDownloads {
            start(target)
        } else {
            downloads[target.id] = .waiting
        }
    }

    /// Stops a running download, or takes a waiting one out of the line.
    public func cancelDownload(_ target: DownloadTarget) {
        if let task = downloadTasks[target.id] {
            task.cancel()
        } else {
            forget(target)
        }
    }

    public func cancelAllDownloads() {
        for job in downloadJobs where job.state.isPending {
            cancelDownload(job.target)
        }
    }

    /// Clears a failed download from the list.
    public func dismissDownload(_ target: DownloadTarget) {
        if downloads[target.id]?.isPending != true {
            forget(target)
        }
    }

    private func start(_ target: DownloadTarget) {
        downloads[target.id] = .inProgress(0)
        downloadTasks[target.id] = Task { [weak self] in
            await self?.performDownload(target)
        }
    }

    private func startNextWaiting() {
        let next = downloadOrder.first { downloads[$0.id] == .waiting }
        if let next, downloadTasks.count < Self.maximumConcurrentDownloads {
            start(next)
        }
    }

    private func forget(_ target: DownloadTarget) {
        downloads[target.id] = nil
        downloadOrder.removeAll { $0.id == target.id }
    }

    /// Downloads an edition to a place the user chose. The app keeps no copy of it.
    @discardableResult
    public func export(_ edition: Edition, of item: LibraryTitle, to destination: URL) -> DownloadTarget {
        let target = locator.exportTarget(for: edition, in: item, destination: destination)
        download(target)
        return target
    }

    /// Removes a downloaded file, or the unpacked contents of an archive, from disk.
    public func deleteDownload(_ target: DownloadTarget) {
        try? FileManager.default.removeItem(at: target.localURL)
        forget(target)
        refreshDownloadedItems()
    }

    /// Waits for every download, including those still waiting their turn. Used by tests.
    public func waitForDownloads() async {
        while let task = downloadTasks.values.first {
            await task.value
        }
    }

    private func performDownload(_ target: DownloadTarget) async {
        let partial = target.partialURL
        do {
            let signed = try await catalog.signedDownloadURL(for: target.remote)
            try await environment.http.download(.get(signed), to: partial) { [weak self] fraction in
                Task { @MainActor in self?.reportProgress(fraction, for: target) }
            }
            try await moveIntoPlace(partial, for: target)
            forget(target)
            finishDownload(target)
        } catch {
            if error is CancellationError || Task.isCancelled {
                forget(target)
            } else {
                downloads[target.id] = .failed(error.localizedDescription)
            }
        }
        try? FileManager.default.removeItem(at: partial)
        downloadTasks[target.id] = nil
        startNextWaiting()
    }

    private func moveIntoPlace(_ partial: URL, for target: DownloadTarget) async throws {
        if target.isArchive {
            // Unpacking a large archive takes seconds; keep it off the main actor.
            try await Task.detached { try ArchiveExtractor().extract(partial, to: target.localURL) }.value
        } else {
            _ = try? FileManager.default.removeItem(at: target.localURL)
            try FileManager.default.moveItem(at: partial, to: target.localURL)
        }
    }

    /// Progress arrives from the network's own queue and may trail the end of the download.
    private func reportProgress(_ fraction: Double, for target: DownloadTarget) {
        if case .inProgress = downloads[target.id] {
            downloads[target.id] = .inProgress(fraction)
        }
    }

    private func finishDownload(_ target: DownloadTarget) {
        if let item = item(id: target.itemID), !item.tags.isEmpty {
            for file in locator.files(in: target) {
                try? tagger.setTags(item.tags, on: file)
            }
        }
        refreshDownloadedItems()
    }
}
