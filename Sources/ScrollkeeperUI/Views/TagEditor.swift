import ScrollkeeperKit
import SwiftUI

/// Shows a title's tags and lets the user add and remove them.
struct TagEditor: View {
    @Environment(LibraryStore.self) private var store
    let item: LibraryTitle
    @State private var newTag = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !item.tags.isEmpty {
                FlowLayout(spacing: 6) {
                    ForEach(item.tags, id: \.self) { tag in
                        TagChip(tag: tag) { store.removeTag(tag, from: item.id) }
                    }
                }
            }
            HStack(spacing: 6) {
                TextField("Add a tag", text: $newTag)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit(addTag)
                Menu {
                    ForEach(suggestions, id: \.self) { tag in
                        Button(tag) { store.addTag(tag, to: item.id) }
                    }
                } label: {
                    Image(systemName: "tag")
                }
                .compactMenuStyle()
                .disabled(suggestions.isEmpty)
                .help("Add a tag you have used before")
            }
            Text(PlatformText.tagsNote)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var suggestions: [String] {
        store.allTags.filter { !item.tags.contains($0) }
    }

    private func addTag() {
        store.addTag(newTag, to: item.id)
        newTag = ""
    }
}

private struct TagChip: View {
    let tag: String
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 4) {
            Text(tag)
            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .help("Remove the tag \(tag)")
        }
        .font(.callout)
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(.quaternary, in: Capsule())
    }
}

/// Lays its subviews out in rows, wrapping to the next row when one is full.
struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache _: inout ()) -> CGSize {
        let arrangement = arrange(subviews, width: proposal.width ?? .infinity)
        return CGSize(width: proposal.width ?? arrangement.size.width, height: arrangement.size.height)
    }

    func placeSubviews(in bounds: CGRect, proposal _: ProposedViewSize, subviews: Subviews, cache _: inout ()) {
        let arrangement = arrange(subviews, width: bounds.width)
        for (subview, origin) in zip(subviews, arrangement.origins) {
            subview.place(at: CGPoint(x: bounds.minX + origin.x, y: bounds.minY + origin.y), proposal: .unspecified)
        }
    }

    private struct Arrangement {
        var origins: [CGPoint] = []
        var size = CGSize.zero
    }

    private func arrange(_ subviews: Subviews, width: CGFloat) -> Arrangement {
        var arrangement = Arrangement()
        var position = CGPoint.zero
        var rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if position.x > 0, position.x + size.width > width {
                position = CGPoint(x: 0, y: position.y + rowHeight + spacing)
                rowHeight = 0
            }
            arrangement.origins.append(position)
            position.x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
            arrangement.size.width = max(arrangement.size.width, position.x - spacing)
        }
        arrangement.size.height = position.y + rowHeight
        return arrangement
    }
}
