import Foundation

extension LibraryStore {
    /// The files to send to the app that asked for a title, downloading the title first when it
    /// is missing or out of date. The download goes through the normal queue.
    public func handoffFiles(for request: HandoffRequest) async throws(HandoffError) -> [URL] {
        await waitUntilLoaded()
        guard account != .signedOut else { throw .signedOut }
        guard let item = item(id: request.sku) else { throw .titleNotFound(sku: request.sku) }
        guard let target = handoffTarget(for: item) else { throw .noEdition(title: item.title) }
        if !isDownloaded(target) || isOutdated(target) {
            download(target)
            await waitForDownload(of: target)
            try checkDownloadFinished(target, of: item)
        }
        let files = request.app.filesToSend(from: files(in: target))
        guard !files.isEmpty else { throw .noAcceptedFiles(title: item.title, app: request.app.name) }
        return files
    }

    /// Writes the list of titles `app` can open and returns where it is, for handing to the app.
    public func handoffIndex(for app: HandoffApp) async throws(HandoffError) -> URL {
        await waitUntilLoaded()
        guard !items.isEmpty else { throw .noCatalog }
        let downloaded = downloadedItemIDs.subtracting(outdatedItemIDs)
        let index = TitleIndex(
            generatedAt: environment.now(), titles: TitleIndex.entries(from: items, downloaded: downloaded, for: app)
        )
        let url = environment.titleIndexURL(for: app)
        do {
            try FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(), withIntermediateDirectories: true
            )
            try index.encoded().write(to: url, options: .atomic)
        } catch {
            throw .indexNotWritten(app: app.name, reason: error.localizedDescription)
        }
        return url
    }

    /// The copy on disk when it is up to date, otherwise the edition the quick actions download.
    func handoffTarget(for item: LibraryTitle) -> DownloadTarget? {
        let actions = quickActions(for: item)
        return actions.isUpdate ? actions.download : actions.open ?? actions.download
    }

    /// A link can arrive while the app is still starting; it waits for the catalog to be read.
    private func waitUntilLoaded() async {
        while !isLoaded {
            try? await Task.sleep(for: .milliseconds(20))
        }
    }

    /// Waits while the download runs or waits its turn behind others.
    private func waitForDownload(of target: DownloadTarget) async {
        while downloads[target.id]?.isPending == true {
            guard let task = downloadTasks[target.id] ?? downloadTasks.values.first else { return }
            await task.value
        }
    }

    private func checkDownloadFinished(_ target: DownloadTarget, of item: LibraryTitle) throws(HandoffError) {
        switch downloads[target.id] {
        case let .failed(reason):
            throw .downloadFailed(title: item.title, reason: reason)
        case .interrupted:
            throw .downloadFailed(title: item.title, reason: "the connection was lost.")
        case .waiting, .inProgress, nil:
            guard isDownloaded(target) else { throw .cancelled(title: item.title) }
        }
    }
}
