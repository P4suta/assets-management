import CoreGraphics
import Foundation
import ImageIO
import Testing

@Test func recognitionChecksRequireExactCompleteText() throws {
    let bounds = CGRect(x: 20, y: 20, width: 200, height: 40)
    let date = [RecognizedFragment(text: "2025/04/01", bounds: bounds)]
    try RenderedTextExpectation.exact(["2025/04/01"]).verify(date)
    try RenderedTextExpectation.exact([]).verify([])
    try RenderedTextExpectation.dates(["2025/04/01"], present: true).verify(date)
    try RenderedTextExpectation.dates(["2025/04/01"], present: false).verify([])
    try RenderedTextExpectation.caption("部屋を追加", leadingPlus: true).verify([
        RecognizedFragment(text: "＋部屋を追加", bounds: bounds)
    ])
}

@Test func recognitionChecksRejectWrongMissingAndAmbiguousText() {
    let bounds = CGRect(x: 20, y: 20, width: 200, height: 40)
    let date = [RecognizedFragment(text: "2025104101", bounds: bounds)]
    #expect(throws: (any Error).self) { try RenderedTextExpectation.exact(["2025/04/01"]).verify(date) }
    #expect(throws: (any Error).self) { try RenderedTextExpectation.exact([]).verify(date) }
    #expect(throws: (any Error).self) { try RenderedTextExpectation.dates(["2025/04/01"], present: true).verify([]) }
    #expect(throws: (any Error).self) {
        try RenderedTextExpectation.dates(["2025/04/01"], present: false).verify([
            RecognizedFragment(text: "2025/04/01", bounds: bounds)
        ])
    }
    for values in [["部屋を…"], ["部屋を追加", "部屋を追加"], ["大部屋を追加"], ["＋部屋を追加"]] {
        #expect(throws: (any Error).self) {
            try RenderedTextExpectation.caption("部屋を追加", leadingPlus: false).verify(
                values.map { RecognizedFragment(text: $0, bounds: bounds) })
        }
    }
}

@Test func captureInventoryRejectsMissingExtraAndDuplicateInputs() throws {
    let expected = RenderedTextInventory.expected
    let count = expected.values.reduce(0, +)
    let identifiers = (0..<count).map { _ in UUID() }
    try RenderedTextInventory.verify(counts: expected, identifiers: identifiers, imageCount: count)
    #expect(throws: RenderedTextFailure.self) {
        try RenderedTextInventory.verify(counts: [:], identifiers: [], imageCount: 0)
    }
    for change in [-1, 1] {
        var counts = expected
        let key = try #require(counts.keys.sorted().first)
        counts[key] = try #require(counts[key]) + change
        #expect(throws: RenderedTextFailure.self) {
            try RenderedTextInventory.verify(counts: counts, identifiers: identifiers, imageCount: count)
        }
        #expect(throws: RenderedTextFailure.self) {
            try RenderedTextInventory.verify(counts: expected, identifiers: identifiers, imageCount: count + change)
        }
    }
    var duplicate = identifiers
    duplicate[1] = duplicate[0]
    #expect(throws: RenderedTextFailure.self) {
        try RenderedTextInventory.verify(counts: expected, identifiers: duplicate, imageCount: count)
    }
}

#if os(macOS)
private struct ExportedTest: Decodable {
    let testIdentifier: String
    let attachments: [ExportedAttachment]
}

private struct ExportedAttachment: Decodable {
    let exportedFileName: String
    let suggestedHumanReadableName: String
}

private func captureData(_ name: String, in directory: URL, limit: Int) throws -> Data {
    try #require(!name.isEmpty && (name as NSString).lastPathComponent == name && name != "." && name != "..")
    let url = directory.appendingPathComponent(name)
    let values = try url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey])
    try #require(values.isRegularFile == true && values.isSymbolicLink == false)
    let size = try #require(values.fileSize)
    try #require(size > 0 && size <= limit)
    return try Data(contentsOf: url)
}

@Test func exportedCapturesPassEveryRecognitionExpectation() throws {
    let path = try #require(ProcessInfo.processInfo.environment["NATIVE_TEXT_CAPTURE_PATH"])
    try #require(path.hasPrefix("/"))
    let directory = URL(fileURLWithPath: path, isDirectory: true)
    let manifest = try JSONDecoder().decode([ExportedTest].self,
        from: captureData("manifest.json", in: directory, limit: 4_000_000))
    var inputs: [(RenderedTextCheck, ExportedAttachment)] = []
    var counts: [String: Int] = [:]
    var imageCount = 0
    for test in manifest {
        imageCount += test.attachments.filter { $0.suggestedHumanReadableName.hasPrefix(RenderedTextCheck.imagePrefix) }.count
        for attachment in test.attachments where attachment.suggestedHumanReadableName.hasPrefix(RenderedTextCheck.requestPrefix) {
            let check = try JSONDecoder().decode(RenderedTextCheck.self,
                from: captureData(attachment.exportedFileName, in: directory, limit: 64_000))
            try #require(attachment.suggestedHumanReadableName.hasPrefix(RenderedTextCheck.requestPrefix + check.id.uuidString + "_"))
            let matches = test.attachments.filter {
                $0.suggestedHumanReadableName.hasPrefix(RenderedTextCheck.imagePrefix + check.id.uuidString + "_")
            }
            try #require(matches.count == 1)
            inputs.append((check, try #require(matches.first)))
            counts[test.testIdentifier, default: 0] += 1
        }
    }
    try RenderedTextInventory.verify(counts: counts, identifiers: inputs.map { $0.0.id }, imageCount: imageCount)
    for (check, attachment) in inputs {
        let data = try captureData(attachment.exportedFileName, in: directory, limit: 16_000_000)
        let source = try #require(CGImageSourceCreateWithData(data as CFData, nil))
        try #require(CGImageSourceGetCount(source) == 1)
        let image = try #require(CGImageSourceCreateImageAtIndex(source, 0, nil))
        let fragments = try NativeTextRecognition.recognize(image, languages: check.languages)
        do {
            try check.expectation.verify(fragments)
        } catch {
            Attachment.record(data, named: "Rejected native text input.png")
            Issue.record(error, "Check: \(check). Fragments: \(fragments).")
        }
    }
}
#endif
