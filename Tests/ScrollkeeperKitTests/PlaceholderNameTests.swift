import Foundation
@testable import ScrollkeeperKit
import Testing

@Suite struct PlaceholderNameTests {
    private let grouper = EntitlementGrouper()

    @Test(arguments: [
        ("Test", true), (" test ", true), ("Accidental duplicate package - disregard", true),
        ("Do not use", true), ("Placeholder", true),
        ("Starfinder Player Core PDF - File per Chapter", false), ("Pathfinder Test of Ages", false),
        ("Testament of Fire", false)
    ])
    func recognizesPlaceholderNames(name: String, isPlaceholder: Bool) {
        #expect(PlaceholderNames.isPlaceholder(name) == isPlaceholder)
    }

    @Test func loneSingleFileIsNamedFromTheProduct() {
        let entitlements = [
            Fixtures.entitlement("Accidental duplicate package - disregard", sku: "PZO22001E", file: "PZO22001E.pdf",
                                 productName: "Starfinder Player Core PDF"),
            Fixtures.entitlement("Starfinder Player Core PDF - File per Chapter", sku: "PZO22001E", file: "c.zip",
                                 productName: "Starfinder Player Core PDF")
        ]
        let item = grouper.makeItems(from: CatalogSnapshot(entitlements: entitlements))[0]
        #expect(item.title == "Starfinder Player Core")
        #expect(item.editions.map(\.label) == ["Single File", "File per Chapter"])
        #expect(item.editions[0].entitlement.displayName == "Starfinder Player Core PDF - Single File")
    }

    @Test func placeholderBesideANamedTwinTakesItsNameAndDate() throws {
        var test = Fixtures.entitlement("Test", sku: "PZO13007E", file: "PZO13007E.pdf",
                                        productName: "Pathfinder Lost Omens Draconic Codex PDF")
        test.dateUpdated = try #require(ISO8601DateFormatter().date(from: "2026-09-21T10:00:00Z"))
        let named = Fixtures.entitlement(
            "Pathfinder Lost Omens Draconic Codex PDF - Single File ", sku: "PZO13007E", file: "x-PZO13007E.pdf",
            productName: "Pathfinder Lost Omens Draconic Codex PDF"
        )
        let item = grouper.makeItems(from: CatalogSnapshot(entitlements: [test, named]))[0]
        let names = item.editions.map(\.entitlement.displayName)
        #expect(names.contains("Pathfinder Lost Omens Draconic Codex PDF - Single File (updated 2026-09-21)"))
        #expect(names.contains("Pathfinder Lost Omens Draconic Codex PDF - Single File "))
        #expect(Set(item.editions.map(\.label)) == ["Single File", "Single File (updated 2026-09-21)"])
    }

    @Test func archivesOnlyTakeTheNameOfArchivesWithTheSameNumberOfFiles() {
        var test = Fixtures.entitlement("Test", sku: "S", file: "a.zip", productName: "Some Book PDF")
        test.assetCount = 21
        let maps = Fixtures.entitlement("Some Book PDF - Maps", sku: "S", file: "m.zip", productName: "Some Book PDF")
        let item = grouper.makeItems(from: CatalogSnapshot(entitlements: [test, maps]))[0]
        #expect(item.editions.map(\.entitlement.displayName).contains("Some Book PDF"))
    }

    @Test func undatedTwinsAreToldApartByPackage() {
        let test = Fixtures.entitlement("Test", sku: "S", file: "a.pdf", productName: "Some Book PDF")
        let named = Fixtures.entitlement("Some Book PDF - Single File", sku: "S", file: "b.pdf",
                                         productName: "Some Book PDF")
        let names = grouper.makeItems(from: CatalogSnapshot(entitlements: [test, named]))[0].editions
            .map(\.entitlement.displayName)
        #expect(names.contains("Some Book PDF - Single File (package pkg-Test)"))
    }

    @Test func placeholderWithoutAProductNameIsLeftAlone() {
        let entitlement = Fixtures.entitlement("Test", sku: "S")
        #expect(PlaceholderNames.repairing([entitlement]) == [entitlement])
    }
}
