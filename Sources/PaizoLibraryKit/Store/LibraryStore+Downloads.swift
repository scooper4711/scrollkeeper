import Foundation

extension LibraryStore {
    public func isDownloaded(_ target: DownloadTarget) -> Bool {
        locator.isDownloaded(target)
    }

    /// The downloaded file, or the unpacked files of an archive. Empty when not downloaded.
    public func files(in target: DownloadTarget) -> [URL] {
        locator.files(in: target)
    }

    /// Starts downloading the file unless it is already on its way. The zip of a PDF edition is
    /// unpacked into its folder and then removed.
    public func download(_ target: DownloadTarget) {
        if case .inProgress = downloads[target.id] {
            return
        }
        downloads[target.id] = .inProgress(0)
        downloadTasks[target.id] = Task { [weak self] in
            await self?.performDownload(target)
        }
    }

    public func cancelDownload(_ target: DownloadTarget) {
        downloadTasks[target.id]?.cancel()
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
        downloads[target.id] = nil
        refreshDownloadedItems()
    }

    /// Waits for every download in progress. Used by tests.
    public func waitForDownloads() async {
        for task in downloadTasks.values {
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
            downloads[target.id] = nil
            finishDownload(target)
        } catch {
            downloads[target.id] = error is CancellationError || Task.isCancelled
                ? nil
                : .failed(error.localizedDescription)
        }
        try? FileManager.default.removeItem(at: partial)
        downloadTasks[target.id] = nil
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
