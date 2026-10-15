import Foundation

extension LibraryStore {
    /// The files to send to the app that asked for a title, downloading the title first when it
    /// is missing or out of date. The download goes through the normal queue.
    public func handoffFiles(for request: HandoffRequest) async throws(HandoffError) -> [URL] {
        guard account != .signedOut else { throw .signedOut }
        guard let item = item(id: request.sku) else { throw .titleNotFound(sku: request.sku) }
        guard let target = handoffTarget(for: item) else { throw .noEdition(title: item.title) }
        if !isDownloaded(target) || isOutdated(target) {
            download(target)
            await waitForDownload(of: target)
            try checkDownloadFinished(target, of: item)
        }
        let files = files(in: target).filter(request.app.accepts)
        guard !files.isEmpty else { throw .noAcceptedFiles(title: item.title, app: request.app.name) }
        return files
    }

    /// The copy on disk when it is up to date, otherwise the edition the quick actions download.
    func handoffTarget(for item: LibraryTitle) -> DownloadTarget? {
        let actions = quickActions(for: item)
        return actions.isUpdate ? actions.download : actions.open ?? actions.download
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
