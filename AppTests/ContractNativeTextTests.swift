import PropertyCore
import SwiftUI
import Testing
import UIKit
@testable import PropertyRecords

extension NativePresentationTests {
    @Test(arguments: [420, 1032])
    func nativeContractLabelsFitAtTheLargestTextSize(width: Int) async throws {
        let directory = URL.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let repository = FileRecordsRepository(directory: directory)
        let records = try SampleRecords.make()
        try await repository.save(records)
        let store = RecordsStore(repository: repository)
        await store.load()
        let scene = try #require(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(x: 0, y: 0, width: CGFloat(width), height: 1376)
        let session = EditorSession(ContractFields(start: Date(), end: Date()))
        let controller = UIHostingController(rootView: ContractEditor(session: session, roomID: records.rooms[0].id)
            .environment(store).environment(AppNotices()).environment(\.locale, Locale(identifier: "ja_JP")))
        controller.traitOverrides.preferredContentSizeCategory = .accessibilityExtraExtraExtraLarge
        window.rootViewController = controller
        window.isHidden = false
        defer { window.isHidden = true; window.rootViewController = nil }
        func descendants(_ view: UIView) -> [UIView] { [view] + view.subviews.flatMap(descendants) }
        let deadline = ContinuousClock.now.advanced(by: .seconds(5))
        repeat {
            controller.view.layoutIfNeeded()
            if descendants(controller.view).compactMap({ $0 as? UIDatePicker }).count >= 2 { break }
            try await Task.sleep(for: .milliseconds(10))
        } while ContinuousClock.now < deadline
        #expect(descendants(controller.view).compactMap { $0 as? UIDatePicker }.count >= 2)
        let image = UIGraphicsImageRenderer(size: window.bounds.size).image { _ in
            #expect(window.drawHierarchy(in: window.bounds, afterScreenUpdates: true))
        }
        Attachment.record(try #require(image.pngData()), named: "Native contract at width \(width).png")
        let labels = descendants(controller.view).compactMap { $0 as? UILabel }
        #expect(!labels.isEmpty)
        let dateLabels = labels.filter {
            $0.text?.range(of: "^[0-9]{4}/[0-9]{2}/[0-9]{2}$", options: .regularExpression) != nil
        }
        #expect(dateLabels.count == 2)
        for label in dateLabels {
            #expect(!label.isHidden && label.alpha > 0)
            #expect(!label.bounds.isEmpty && window.bounds.contains(label.convert(label.bounds, to: window)))
        }
        var observations: [String] = []
        for label in labels {
            guard let text = label.text, !text.isEmpty, let font = label.font else { continue }
            let required = (text as NSString).boundingRect(with: CGSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude),
                options: .usesLineFragmentOrigin, attributes: [.font: font], context: nil)
            let attributed = label.attributedText?.boundingRect(with: CGSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude),
                options: .usesLineFragmentOrigin, context: nil)
            let frame = label.convert(label.bounds, to: window)
            observations.append("\(text): font=\(font), bounds=\(label.bounds), frame=\(frame), hidden=\(label.isHidden), alpha=\(label.alpha), required=\(required), attributed=\(String(describing: attributed)), attributes=\(String(describing: label.attributedText)), shrink=\(label.adjustsFontSizeToFitWidth), minimumScale=\(label.minimumScaleFactor), tightening=\(label.allowsDefaultTighteningForTruncation), textRect=\(label.textRect(forBounds: label.bounds, limitedToNumberOfLines: label.numberOfLines))")
            guard !label.isHidden, label.alpha > 0, window.bounds.contains(frame), !frame.isEmpty else { continue }
            if label.numberOfLines == 1 {
                let minimum = label.adjustsFontSizeToFitWidth ? CGFloat(label.minimumScaleFactor) : 1
                #expect(minimum > 0 && minimum <= 1)
                #expect(label.bounds.width + 1 >= required.width * minimum, "Native label width: \(text)")
                #expect(label.bounds.height + 1 >= required.height, "Native label height: \(text)")
                #expect(label.bounds.contains(label.textRect(forBounds: label.bounds, limitedToNumberOfLines: 1)))
                if label.adjustsFontSizeToFitWidth {
                    #expect(font.pointSize * minimum >= UIFont.preferredFont(forTextStyle: .body,
                        compatibleWith: UITraitCollection(preferredContentSizeCategory: .large)).pointSize * 2)
                }
            }
        }
        Attachment.record(observations.joined(separator: "\n"), named: "Native contract labels at width \(width).txt")
    }
}
