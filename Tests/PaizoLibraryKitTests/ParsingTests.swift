import Foundation
@testable import PaizoLibraryKit
import Testing

@Suite struct TitleNormalizerTests {
    @Test(arguments: [
        ("Pathfinder NPC Core PDF - File per Chapter", "Pathfinder NPC Core"),
        ("Pathfinder NPC Core PDF - Singel File", "Pathfinder NPC Core"),
        ("PZO22005E Starfinder Galactic Ancestries File-Per-Chapter PDF", "Starfinder Galactic Ancestries"),
        ("PZO14009E - Pathfinder Adventure: Troubles in Grayce PDF", "Pathfinder Adventure: Troubles in Grayce"),
        ("Pathfinder Tales: The Ironroot Deception ePub (Download)", "Pathfinder Tales: The Ironroot Deception"),
        ("The Crusader Road ePub/PDF", "The Crusader Road"),
        ("Starfinder Adventure: Tales from the Vast PDF (File-Per-Chapter)",
         "Starfinder Adventure: Tales from the Vast"),
        ("Pathfinder Flip-Mat: Boarding School - PDF", "Pathfinder Flip-Mat: Boarding School"),
        ("Mummy\u{2019}s Mask PDFs", "Mummy's Mask"),
        ("Pathfinder Society Scenario #3-25: Storming the Gate", "Pathfinder Society Scenario #3-25: Storming the Gate")
    ])
    func baseTitleStripsSKUAndFormatSuffixes(name: String, expected: String) {
        #expect(TitleNormalizer.baseTitle(name) == expected)
    }

    @Test(arguments: [
        ("Book PDF - Single File", "pdf", EditionKind.singleFile),
        ("Book PDF - Single FIle", "pdf", .singleFile),
        ("Book PDF (Single-File)", "pdf", .singleFile),
        ("Book PDF - File per Chatper", "zip", .filePerChapter),
        ("Book PDF - File Per Chapter", "zip", .filePerChapter),
        ("Book PDF - Lite Single File", "pdf", .liteSingleFile),
        ("Book PDF - Lite File per Chapter", "zip", .liteFilePerChapter),
        ("Novel ePub", "epub", .epub),
        ("Flip-Mat PDF", "pdf", .other)
    ])
    func editionKindToleratesSpellingVariants(name: String, fileExtension: String, expected: EditionKind) {
        #expect(TitleNormalizer.editionKind(displayName: name, fileExtension: fileExtension) == expected)
    }

    @Test func comparisonKeyIgnoresPunctuationAndCase() {
        #expect(TitleNormalizer.comparisonKey("Irrisen - Land of Winter!") == "irrisenlandofwinter")
    }
}

@Suite struct PaizoDateParserTests {
    @Test(arguments: [
        ("Wed Sep 02 2026 20:52:57 GMT+0000 (Coordinated Universal Time)", 1_788_382_377.0),
        ("Wed Sep 02 2026 22:52:57 GMT+0200 (centraleuropeisk sommartid)", 1_788_382_377.0),
        ("2024-11-08 09:45:21", 1_731_059_121.0),
        ("8/25/2022 15:22", 1_661_440_920.0)
    ])
    func parsesKnownFormats(text: String, expected: Double) {
        #expect(PaizoDateParser.parse(text)?.timeIntervalSince1970 == expected)
    }

    @Test func rejectsUnknownFormats() {
        #expect(PaizoDateParser.parse("yesterday") == nil)
        #expect(PaizoDateParser.parse("") == nil)
    }
}

@Suite struct FileNameSanitizerTests {
    @Test func replacesForbiddenCharacters() {
        #expect(FileNameSanitizer.sanitize("Scenario #2-05: File/Corrupted?") == "Scenario #2-05- File-Corrupted-")
    }

    @Test func collapsesWhitespaceAndTrimsDots() {
        #expect(FileNameSanitizer.sanitize("  A   B .") == "A B")
    }

    @Test func neverReturnsAnEmptyName() {
        #expect(FileNameSanitizer.sanitize(" . ") == "Untitled")
    }

    @Test func limitsLength() {
        let long = String(repeating: "a", count: 300)
        #expect(FileNameSanitizer.sanitize(long).count == FileNameSanitizer.maximumLength)
    }
}

@Suite struct TextPatternTests {
    @Test func capturesGroupsOrNothing() {
        let pattern = TextPattern(#"#(\d+)-(\d+)"#)
        #expect(pattern.captures(in: "Scenario #3-25") == ["#3-25", "3", "25"])
        #expect(pattern.captures(in: "no numbers").isEmpty)
    }

    @Test func invalidPatternMatchesNothing() {
        #expect(!TextPattern("(").matches("("))
    }

    @Test func optionalGroupThatDidNotParticipateIsEmpty() {
        #expect(TextPattern(#"a(b)?c"#).captures(in: "ac") == ["ac", ""])
    }
}

@Suite struct FlightPayloadParserTests {
    private let parser = FlightPayloadParser()

    @Test func parsesEntitlementsAcrossChunks() throws {
        let records = [
            Fixtures.record(id: "a", name: "Book One PDF"),
            Fixtures.record(id: "b", name: "Book Two PDF", sku: "PZO2000E", file: "two.zip")
        ]
        let page = try parser.parsePage(html: Fixtures.libraryPageHTML(records: records, count: 120))

        #expect(page.totalCount == 120)
        #expect(!page.tokenExpired)
        #expect(page.entitlements.map(\.packageID) == ["a", "b"])
        #expect(page.entitlements[1].resolvedSKU == "PZO2000E")
        #expect(page.entitlements[1].fileExtension == "zip")
        #expect(page.entitlements[0].dateGranted != nil)
    }

    @Test func reportsExpiredToken() throws {
        let page = try parser.parsePage(html: Fixtures.libraryPageHTML(records: [], count: 0, tokenExpired: true))
        #expect(page.tokenExpired)
    }

    @Test func skipsMalformedRecords() throws {
        let malformed: [String: Any] = ["PackageDisplayName": "No identifier"]
        let records = [malformed, Fixtures.record(id: "ok", name: "Fine")]
        let page = try parser.parsePage(html: Fixtures.libraryPageHTML(records: records, count: 2))
        #expect(page.entitlements.map(\.packageID) == ["ok"])
    }

    @Test func failsWhenPageHasNoListing() {
        #expect(throws: PayloadError.entitlementsMissing) {
            try parser.parsePage(html: "<html><body>Please sign in</body></html>")
        }
        #expect(PayloadError.entitlementsMissing.errorDescription?.contains("library page") == true)
    }
}

@Suite struct EntitlementRecordTests {
    @Test func decodesNumericIdentifiersAndAssets() throws {
        let json: [String: Any] = [
            "DigitalPackageID": 2_086_447,
            "CustomerID": 1001,
            "Product": ["name": "Dark Archive PDF", "sku": "PZO2111E", "images": ["https://cdn.example/a.jpg"]],
            "DigitalPackage": [
                "DisplayName": "Dark Archive",
                "DateLastUpdated": "8/25/2022 15:22",
                "AssetsData": [
                    ["id": 7, "DisplayName": "Chapter 1", "FileType": "PDF", "File": "c1.pdf", "Filepath": "b/c1.pdf"],
                    ["id": "x", "File": "c2.pdf"]
                ]
            ]
        ]
        let record = try JSONDecoder().decode(EntitlementRecord.self, from: Fixtures.jsonData(json))
        let entitlement = record.entitlement

        #expect(entitlement.packageID == "2086447")
        #expect(entitlement.customerID == "1001")
        #expect(entitlement.displayName == "Dark Archive")
        #expect(entitlement.resolvedSKU == "PZO2111E")
        #expect(entitlement.productImageURLs.count == 1)
        #expect(entitlement.dateUpdated != nil)
        #expect(!entitlement.hasFile)
        #expect(record.assets.map(\.id) == ["7", "x"])
        #expect(record.assets[1].displayName == "c2.pdf")
        #expect(record.assets[0].fileExtension == "pdf")
    }

    @Test func undefinedSKUFallsBackToPackageProducts() {
        var entitlement = Entitlement(packageID: "p", displayName: "Scenario")
        entitlement.providedBySKU = "undefined"
        entitlement.productSKUs = ["PZO160714E"]
        #expect(entitlement.resolvedSKU == "PZO160714E")
        entitlement.productSKUs = []
        #expect(entitlement.resolvedSKU.isEmpty)
    }

    @Test func recognisesLegacyStorage() {
        var entitlement = Entitlement(packageID: "p", displayName: "Old")
        entitlement.filePath = "https://s3.us-west-2.amazonaws.com/com.paizo.downloads.raw/PaizoInc./A/A.pdf?X=1"
        #expect(entitlement.isLegacyStorage)
        #expect(entitlement.id == "p")
    }

    @Test func flexibleStringTreatsOtherTypesAsEmpty() throws {
        let decoded = try JSONDecoder().decode([FlexibleString].self, from: Data("[true]".utf8))
        #expect(decoded.first?.value == "")
    }
}
