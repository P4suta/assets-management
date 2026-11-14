import SwiftUI
import Testing
import UIKit

private enum NativeDateArrangement: CaseIterable, Sendable {
    case explicitCompact, bodyFont, unlabeledIntrinsic, expandedUnlabeled, largeControl
    case directDynamicType, windowTraits, presentedWithDynamicType
}

private struct NativeDatePresentationHost: View {
    let form: NativeDateArrangementForm
    @State private var presented = false

    var body: some View {
        Color.clear.onAppear { presented = true }.sheet(isPresented: $presented) { form }
    }
}

private struct NativeDateArrangementForm: View {
    let arrangement: NativeDateArrangement
    @State private var start = Date(timeIntervalSince1970: 1_743_462_000)
    @State private var end = Date(timeIntervalSince1970: 1_806_418_800)

    var body: some View {
        NavigationStack {
            Form {
                date("契約開始日", selection: $start)
                date("契約満了日", selection: $end)
            }
            .navigationTitle("契約を編集")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    @ViewBuilder private func date(_ title: LocalizedStringKey, selection: Binding<Date>) -> some View {
        switch arrangement {
        case .explicitCompact, .directDynamicType, .windowTraits, .presentedWithDynamicType:
            DatePicker(title, selection: selection, displayedComponents: .date).datePickerStyle(.compact)
        case .bodyFont:
            DatePicker(title, selection: selection, displayedComponents: .date).font(.body)
        case .unlabeledIntrinsic:
            VStack(alignment: .leading) {
                Text(title)
                DatePicker(title, selection: selection, displayedComponents: .date).labelsHidden().fixedSize()
            }
        case .expandedUnlabeled:
            VStack(alignment: .leading) {
                Text(title)
                DatePicker(title, selection: selection, displayedComponents: .date).labelsHidden()
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        case .largeControl:
            DatePicker(title, selection: selection, displayedComponents: .date).controlSize(.large)
        }
    }
}

extension NativePresentationTests {
    @Test(arguments: NativeDateArrangement.allCases, [420, 1032])
    fileprivate func captureLargestNativeDateArrangements(arrangement: NativeDateArrangement, width: Int) async throws {
        let scene = try #require(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(x: 0, y: 0, width: CGFloat(width), height: 1376)
        if arrangement == .windowTraits { window.traitOverrides.preferredContentSizeCategory = .accessibilityExtraExtraExtraLarge }
        let form = NativeDateArrangementForm(arrangement: arrangement).environment(\.locale, Locale(identifier: "ja_JP"))
        let root: AnyView
        switch arrangement {
        case .directDynamicType:
            root = AnyView(form.environment(\.dynamicTypeSize, .accessibility5))
        case .presentedWithDynamicType:
            root = AnyView(NativeDatePresentationHost(form: NativeDateArrangementForm(arrangement: arrangement))
                .environment(\.locale, Locale(identifier: "ja_JP")).environment(\.dynamicTypeSize, .accessibility5))
        default:
            root = AnyView(form)
        }
        let controller = UIHostingController(rootView: root)
        controller.traitOverrides.preferredContentSizeCategory = .accessibilityExtraExtraExtraLarge
        window.rootViewController = controller
        window.isHidden = false
        defer { window.isHidden = true; window.rootViewController = nil }
        func descendants(_ view: UIView) -> [UIView] { [view] + view.subviews.flatMap(descendants) }
        let deadline = ContinuousClock.now.advanced(by: .seconds(5))
        repeat {
            controller.view.layoutIfNeeded()
            if descendants(window).compactMap({ $0 as? UIDatePicker }).count == 2 { break }
            try await Task.sleep(for: .milliseconds(10))
        } while ContinuousClock.now < deadline
        let image = UIGraphicsImageRenderer(size: window.bounds.size).image { _ in
            #expect(window.drawHierarchy(in: window.bounds, afterScreenUpdates: true))
        }
        Attachment.record(try #require(image.pngData()), named: "\(arrangement)-\(width).png")
        let labels = descendants(window).compactMap { $0 as? UILabel }.filter {
            $0.text?.range(of: "^[0-9]{4}/[0-9]{2}/[0-9]{2}$", options: .regularExpression) != nil
        }
        #expect(labels.count == 2)
        var observations: [String] = []
        for label in labels {
            let text = try #require(label.text)
            let font = try #require(label.font)
            let required = (text as NSString).size(withAttributes: [.font: font])
            let minimum = label.adjustsFontSizeToFitWidth ? CGFloat(label.minimumScaleFactor) : 1
            let frame = label.convert(label.bounds, to: window)
            let minimumFont = UIFont.preferredFont(forTextStyle: .body,
                compatibleWith: UITraitCollection(preferredContentSizeCategory: .large)).pointSize * 2
            let fits = !label.isHidden && label.alpha > 0 && !frame.isEmpty && window.bounds.contains(frame)
                && minimum > 0 && minimum <= 1 && label.bounds.width + 1 >= required.width * minimum
                && label.bounds.height + 1 >= required.height && font.pointSize * minimum >= minimumFont
            observations.append("\(text): fits=\(fits), font=\(font), bounds=\(label.bounds), frame=\(frame), required=\(required), minimumScale=\(minimum)")
        }
        Attachment.record(observations.joined(separator: "\n"), named: "\(arrangement)-\(width).txt")
    }
}
