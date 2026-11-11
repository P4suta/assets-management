#if DEBUG
import UIKit

@MainActor
enum SamplePDF {
    static func photoData() -> Data? { UIImage(named: "FixturePhoto")?.pngData() }

    static func data(title: String, lines: [String]) -> Data {
        let page = CGRect(x: 0, y: 0, width: 595, height: 842)
        return UIGraphicsPDFRenderer(bounds: page).pdfData { context in
            context.beginPage()
            UIColor.white.setFill()
            context.fill(page)
            let attributes: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 20), .foregroundColor: UIColor.black]
            let heading: [NSAttributedString.Key: Any] = [.font: UIFont.boldSystemFont(ofSize: 30), .foregroundColor: UIColor.black]
            (title as NSString).draw(in: CGRect(x: 48, y: 60, width: 499, height: 60), withAttributes: heading)
            for (index, line) in lines.enumerated() {
                (line as NSString).draw(in: CGRect(x: 48, y: 150 + index * 65, width: 499, height: 60), withAttributes: attributes)
            }
        }
    }
}
#endif
