import SwiftUI

#if os(macOS)
import AppKit

typealias PlatformImage = NSImage
#else
import UIKit

typealias PlatformImage = UIImage
#endif

extension PlatformImage {
    static func load(from url: URL) -> PlatformImage? {
        #if os(macOS)
        NSImage(contentsOf: url)
        #else
        UIImage(contentsOfFile: url.path)
        #endif
    }
}

extension Image {
    init(platformImage: PlatformImage) {
        #if os(macOS)
        self.init(nsImage: platformImage)
        #else
        self.init(uiImage: platformImage)
        #endif
    }
}

extension View {
    /// A menu drawn as a bare icon. On the iPad menus already look like that.
    @ViewBuilder
    func compactMenuStyle() -> some View {
        #if os(macOS)
        menuStyle(.borderlessButton).fixedSize()
        #else
        self
        #endif
    }
}

/// Names that differ between the Mac and the iPad.
enum PlatformText {
    #if os(macOS)
    static let showInFileBrowser = "Show in Finder"
    static let tagsNote = "Tags are also set as Finder tags on this title's downloaded files."
    #else
    static let showInFileBrowser = "Show in Files"
    static let tagsNote = "Tags are kept in this app."
    #endif
}
