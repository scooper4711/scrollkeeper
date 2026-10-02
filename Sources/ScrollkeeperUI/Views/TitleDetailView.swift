import ScrollkeeperKit
import SwiftUI

/// Everything about the selected title: cover, facts, summary, editions and tags.
struct TitleDetailView: View {
    let item: LibraryTitle?

    var body: some View {
        if let item {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    header(item)
                    FactsGrid(item: item)
                    section("Downloads") {
                        ForEach(item.editions) { edition in
                            EditionRow(item: item, edition: edition)
                            if edition.id != item.editions.last?.id {
                                Divider()
                            }
                        }
                    }
                    section("Tags") { TagEditor(item: item) }
                    if !item.metadata.summary.isEmpty {
                        section("Summary") {
                            Text(item.metadata.summary)
                                .textSelection(.enabled)
                                .fixedSize(horizontal: false, vertical: true)
                            Text(AboutInfo.contentCredit)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        } else {
            ContentUnavailableView("No Title Selected", systemImage: "book.closed")
        }
    }

    private func header(_ item: LibraryTitle) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            CoverImage(item: item)
                .frame(maxWidth: .infinity, maxHeight: 300)
            Text(item.title)
                .font(.title3)
                .fontWeight(.semibold)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
            if let storeURL = item.metadata.storeURL {
                Link("View on paizo.com", destination: storeURL)
                    .font(.callout)
            }
        }
    }

    private func section(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.headline)
            content()
        }
    }
}

/// The classification and metadata of a title as label–value rows.
private struct FactsGrid: View {
    let item: LibraryTitle

    var body: some View {
        Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: 12, verticalSpacing: 4) {
            ForEach(facts, id: \.label) { fact in
                GridRow {
                    Text(fact.label)
                        .foregroundStyle(.secondary)
                        .gridColumnAlignment(.trailing)
                    Text(fact.value)
                        .textSelection(.enabled)
                }
            }
        }
        .font(.callout)
    }

    private var facts: [(label: String, value: String)] {
        let classification = item.classification
        let added = item.dateAdded == .distantPast ? "" : item.dateAdded.formatted(date: .abbreviated, time: .omitted)
        let all: [(label: String, value: String)] = [
            ("Type", classification.productLine.label),
            ("Game", classification.gameSystem.label),
            ("Author", item.author),
            ("Series", [classification.series, classification.part].filter { !$0.isEmpty }.joined(separator: ", ")),
            ("Number", classification.number.map(String.init) ?? ""),
            ("Level", classification.levelLabel),
            ("Pages", item.pageCount > 0 ? String(item.pageCount) : ""),
            ("Category", item.metadata.categoryPath.joined(separator: " › ")),
            ("Formats", item.formatsLabel),
            ("Released", item.releasedLabel),
            ("Added", added),
            ("SKU", item.sku)
        ]
        return all.filter { !$0.value.isEmpty }
    }
}
