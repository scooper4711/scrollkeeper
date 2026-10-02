import ScrollkeeperKit
import SwiftUI

/// Decoded cover images, kept while there is memory to spare.
@MainActor
final class CoverImageCache {
    static let shared = CoverImageCache()

    private let cache = NSCache<NSURL, PlatformImage>()

    private init() {
        cache.countLimit = 600
    }

    func image(at url: URL) -> PlatformImage? {
        if let cached = cache.object(forKey: url as NSURL) {
            return cached
        }
        guard let image = PlatformImage.load(from: url) else { return nil }
        cache.setObject(image, forKey: url as NSURL)
        return image
    }
}

/// The cover of a title, or a placeholder showing its type while no artwork is available.
struct CoverImage: View {
    @Environment(LibraryStore.self) private var store
    let item: LibraryTitle

    var body: some View {
        if let url = store.coverURL(for: item), let image = CoverImageCache.shared.image(at: url) {
            Image(platformImage: image)
                .resizable()
                .scaledToFit()
                .clipShape(RoundedRectangle(cornerRadius: 4))
                .shadow(color: .black.opacity(0.25), radius: 2, y: 1)
        } else {
            placeholder
        }
    }

    private var placeholder: some View {
        RoundedRectangle(cornerRadius: 4)
            .fill(.quaternary)
            .aspectRatio(0.77, contentMode: .fit)
            .overlay {
                Image(systemName: item.classification.productLine.symbolName)
                    .font(.title)
                    .foregroundStyle(.secondary)
            }
    }
}
