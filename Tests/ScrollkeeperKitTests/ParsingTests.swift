import Foundation
@testable import ScrollkeeperKit
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

    @Test(arguments: [
        ("6/26/2024 7:00:00 AM", "2024-06-26"),
        ("11/20/2024 8:00:00 AM", "2024-11-20"),
        ("8/4/2011", "2011-08-04"),
        (" 12/31/2024 ", "2024-12-31"),
        // Three in the morning UTC is still the evening before at Paizo's offices.
        ("1/1/2025 3:00:00 AM", "2024-12-31")
    ])
    func readsTheReleaseDay(text: String, expected: String) {
        let day = PaizoDateParser.parseReleaseDay(text)
        #expect(day?.formatted(.iso8601.year().month().day()) == expected)
        #expect(day?.formatted(.iso8601.time(includingFractionalSeconds: false)) == "12:00:00")
    }

    @Test(arguments: ["", "soon", "2024-06-26", "13/45/2024"])
    func ignoresReleaseDatesItCannotRead(text: String) {
        #expect(PaizoDateParser.parseReleaseDay(text) == nil)
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

    @Test func parsesAPageDeliveredAsOneVeryLargeChunk() throws {
        // Paizo sometimes sends the whole listing as a single chunk of several hundred kilobytes.
        let summary = String(repeating: "A long description with \"quotes\" and back\\slashes. ", count: 40)
        let records = (1...400).map { Fixtures.record(id: "p\($0)", name: "Book \($0) " + summary) }
        let row = "4:" + Fixtures.jsonString(["$", "$Lb", NSNull(), ["entitlements": records, "count": 400]])
        let html = "<script>self.__next_f.push([1,\(Fixtures.jsonString(row + "\n"))])</script>"
        #expect(html.utf8.count > 500_000)

        let page = try parser.parsePage(html: html)
        #expect(page.entitlements.count == 400)
        #expect(page.entitlements[399].displayName.hasSuffix("back\\slashes. "))
    }

    @Test func joinsAnEscapeSequenceSplitAcrossChunks() throws {
        let properties: [String: Any] = [
            "entitlements": [["DigitalPackageID": "a", "PackageDisplayName": "Dice \u{1F3B2} Tower"]], "count": 1
        ]
        let row = "4:" + Fixtures.jsonString(["$", "$Lb", NSNull(), properties]) + "\n"
        // The die is written as a surrogate pair, and the chunk boundary falls between its halves.
        let literal = String(Fixtures.jsonString(row).dropFirst().dropLast())
            .replacingOccurrences(of: "\u{1F3B2}", with: #"\ud83c\udfb2"#)
        let halves = literal.components(separatedBy: #"\udfb2"#)
        let html = """
        <script>self.__next_f.push([1,"\(halves[0])"])</script>
        <script>self.__next_f.push([1,"\\udfb2\(halves[1])"])</script>
        """

        let page = try parser.parsePage(html: html)
        #expect(page.entitlements.first?.displayName == "Dice \u{1F3B2} Tower")
    }

    @Test func unterminatedChunkIsIgnored() {
        #expect(throws: PayloadError.entitlementsMissing) {
            try parser.parsePage(html: #"<script>self.__next_f.push([1,"4:[\"entitlements\"#)
        }
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
    @Test func decodesNumericIdentifiers() throws {
        let json: [String: Any] = [
            "DigitalPackageID": 2_086_447,
            "CustomerID": 1001,
            "Product": ["name": "Dark Archive PDF", "sku": "PZO2111E", "images": ["https://cdn.example/a.jpg"]],
            "DigitalPackage": [
                "DisplayName": "Dark Archive",
                "DateLastUpdated": "8/25/2022 15:22",
                "DigitalAssets": [7, "x"]
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
        #expect(entitlement.assetCount == 2)
        #expect(!entitlement.isArchive)
    }

    @Test func undefinedSKUFallsBackToPackageProducts() {
        var entitlement = Entitlement(packageID: "p", displayName: "Scenario")
        entitlement.providedBySKU = "undefined"
        entitlement.productSKUs = ["PZO160714E"]
        #expect(entitlement.resolvedSKU == "PZO160714E")
        entitlement.productSKUs = []
        #expect(entitlement.resolvedSKU.isEmpty)
    }

    @Test func recognizesLegacyStorage() {
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
