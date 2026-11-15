import Foundation
import Testing

private struct NativeRule {
    let pattern: String
    let rejected: String
    let accepted: String
}

private let nativeRules = [
    NativeRule(pattern: #"Color\s*\(\s*(red:|hue:|white:)"#,
               rejected: "Color(red: 0.1, green: 0.2, blue: 0.3)", accepted: "Color(uiColor: .systemBackground)"),
    NativeRule(pattern: #"\.(preferredColorScheme|toolbarBackground|presentationBackground|glassEffect)\s*\("#,
               rejected: ".glassEffect(.regular)", accepted: "NavigationStack { List { Text(title) } }"),
    NativeRule(pattern: #"\.(lineLimit|minimumScaleFactor|truncationMode)\s*\("#,
               rejected: ".lineLimit(1)", accepted: "Text(title).font(.body)"),
    NativeRule(pattern: #"\.font\s*\(\s*\.system\s*\(\s*size:"#,
               rejected: ".font(.system(size: 17))", accepted: ".font(.body)"),
    NativeRule(pattern: #"foregroundStyle\s*\(\s*\.(primary|secondary|tertiary)\s*\)"#,
               rejected: ".foregroundStyle(.secondary)", accepted: ".foregroundStyle(Color.secondary)"),
    NativeRule(pattern: #"UIRequiresFullScreen|UIDesignRequiresCompatibility|UIUserInterfaceStyle"#,
               rejected: "UIDesignRequiresCompatibility", accepted: "NSCameraUsageDescription"),
    NativeRule(pattern: #"UIScreen\s*\.\s*main\b"#,
               rejected: "UIScreen.main.bounds", accepted: "GeometryReader { proxy in Text(title) }"),
    NativeRule(pattern: #"UIDevice\s*\.\s*current\s*\.\s*(orientation|userInterfaceIdiom)\b"#,
               rejected: "UIDevice.current.orientation", accepted: "NavigationSplitView { List { Text(title) } } detail: { detail }"),
    NativeRule(pattern: #"UIApplication\s*\.\s*shared\s*\.\s*(windows|connectedScenes)\b"#,
               rejected: "UIApplication.shared.connectedScenes", accepted: "view.window?.windowScene"),
    NativeRule(pattern: #"UIApplication\s*\.\s*shared\s*\.\s*(open|openURL)\s*\("#,
               rejected: "UIApplication.shared.open(url)", accepted: "openURL(url)")
]

@Test func nativeDesignRulesRejectViolationsAndAcceptSystemComponents() throws {
    for rule in nativeRules {
        let expression = try NSRegularExpression(pattern: rule.pattern)
        #expect(expression.firstMatch(in: rule.rejected, range: NSRange(rule.rejected.startIndex..., in: rule.rejected)) != nil)
        #expect(expression.firstMatch(in: rule.accepted, range: NSRange(rule.accepted.startIndex..., in: rule.accepted)) == nil)
    }
}

@Test func appSourceKeepsNativeAppearanceAndTextReflow() throws {
    let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    let directory = root.appendingPathComponent("App")
    let enumerator = try #require(FileManager.default.enumerator(at: directory, includingPropertiesForKeys: nil))
    var scanned = 0
    for case let file as URL in enumerator where ["swift", "plist"].contains(file.pathExtension) {
        let source = try String(contentsOf: file, encoding: .utf8)
        scanned += 1
        for rule in nativeRules {
            let expression = try NSRegularExpression(pattern: rule.pattern)
            #expect(expression.firstMatch(in: source, range: NSRange(source.startIndex..., in: source)) == nil,
                    "Native design policy violation in \(file.lastPathComponent): \(rule.pattern)")
        }
    }
    #expect(scanned >= 10)
}

private struct NativeUISelection {
    var only: Set<String> = []
    var skipped: Set<String> = []

    init(_ command: String) {
        for argument in command.split(whereSeparator: \.isWhitespace) {
            let flag = argument.trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
            if flag.hasPrefix("-only-testing:") { only.insert(String(flag.dropFirst("-only-testing:".count))) }
            if flag.hasPrefix("-skip-testing:") { skipped.insert(String(flag.dropFirst("-skip-testing:".count))) }
        }
    }
}

private struct NativeUIPartition {
    var full: NativeUISelection
    var workflows: NativeUISelection
    var layout: NativeUISelection

    var accepts: Bool {
        full.only.isEmpty && workflows.only.isEmpty && layout.skipped.isEmpty && !layout.only.isEmpty
            && workflows.skipped == full.skipped.union(layout.only)
            && full.skipped.allSatisfy { excluded in
                layout.only.allSatisfy { selected in
                    excluded != selected && !excluded.hasPrefix(selected + "/") && !selected.hasPrefix(excluded + "/")
                }
            }
    }
}

@Test func nativeAcceptancePartitionsCoverTheFullInterfaceInventory() throws {
    let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    let source = try String(contentsOf: root.appendingPathComponent("justfile"), encoding: .utf8)
    func selection(_ name: String) throws -> NativeUISelection {
        let marker = try #require(source.range(of: "\n" + name + ": generate\n"))
        let command = try #require(source[marker.upperBound...].components(separatedBy: "\n\n").first)
        return NativeUISelection(command)
    }
    let partition = try NativeUIPartition(full: selection("ui-test"), workflows: selection("ui-workflow-test"), layout: selection("ui-layout-test"))
    #expect(partition.accepts)
}

@Test func nativeAcceptancePartitionRejectsMissingAndOverlappingJourneys() {
    let probe = "PropertyRecordsUITests/PropertyRecordsUITests/testSystemSettingsAuditProbe()"
    let adaptive = "PropertyRecordsUITests/AdaptiveRecordLayoutTests"
    let tour = "PropertyRecordsUITests/PropertyRecordsUITests/testScreenTourAccessibility()"
    let complete = NativeUIPartition(full: NativeUISelection("'-skip-testing:\(probe)'"),
        workflows: NativeUISelection("'-skip-testing:\(probe)' '-skip-testing:\(adaptive)' '-skip-testing:\(tour)'"),
        layout: NativeUISelection("'-only-testing:\(adaptive)' '-only-testing:\(tour)'"))
    #expect(complete.accepts)
    let rejected: [(inout NativeUIPartition) -> Void] = [
        { $0.full.only.insert(tour) }, { $0.workflows.only.insert(tour) },
        { $0.workflows.skipped.remove(adaptive) }, { $0.workflows.skipped.insert("UncoveredTests") },
        { $0.layout.only = [] }, { $0.layout.only.remove(tour) }, { $0.layout.skipped.insert(tour) },
        { $0.layout.only.insert(probe); $0.workflows.skipped.insert(probe) },
        { $0.layout.only.insert("PropertyRecordsUITests/PropertyRecordsUITests");
          $0.workflows.skipped.insert("PropertyRecordsUITests/PropertyRecordsUITests") }
    ]
    for reject in rejected {
        var partition = complete
        reject(&partition)
        #expect(!partition.accepts)
    }
}
