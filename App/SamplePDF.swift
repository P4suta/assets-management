#if DEBUG
import UIKit

@MainActor
enum SamplePDF {
    static func photoData() -> Data? {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let image = UIGraphicsImageRenderer(size: CGSize(width: 1_000, height: 700), format: format).image { context in
            UIColor.white.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 1_000, height: 700))
            let pipe = UIBezierPath()
            pipe.move(to: CGPoint(x: 140, y: 220))
            pipe.addLine(to: CGPoint(x: 600, y: 220))
            pipe.addLine(to: CGPoint(x: 600, y: 490))
            pipe.addLine(to: CGPoint(x: 860, y: 490))
            pipe.lineCapStyle = .round
            pipe.lineJoinStyle = .round
            UIColor.black.setStroke()
            pipe.lineWidth = 32
            pipe.stroke()
            UIColor.white.setStroke()
            pipe.lineWidth = 20
            pipe.stroke()
            UIColor.black.setStroke()
            let joint = UIBezierPath(rect: CGRect(x: 574, y: 335, width: 52, height: 32))
            joint.lineWidth = 4
            joint.stroke()
            let inspection = UIBezierPath(ovalIn: CGRect(x: 525, y: 276, width: 150, height: 150))
            inspection.lineWidth = 4
            inspection.stroke()
            let pointer = UIBezierPath()
            pointer.move(to: CGPoint(x: 543, y: 402))
            pointer.addLine(to: CGPoint(x: 420, y: 520))
            pointer.lineWidth = 3
            pointer.stroke()
            let title: [NSAttributedString.Key: Any] = [.font: UIFont.boldSystemFont(ofSize: 36), .foregroundColor: UIColor.black]
            let caption: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 28), .foregroundColor: UIColor.black]
            ("配管の確認箇所" as NSString).draw(at: CGPoint(x: 64, y: 54), withAttributes: title)
            ("接続部" as NSString).draw(at: CGPoint(x: 288, y: 530), withAttributes: caption)
            ("サンプル画像" as NSString).draw(at: CGPoint(x: 64, y: 624), withAttributes: caption)
        }
        return image.pngData()
    }

    static func data(title: String, lines: [String], link: URL? = nil) -> Data {
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
            if let link {
                let label = CGRect(x: 48, y: 690, width: 499, height: 44)
                var linkAttributes = attributes
                linkAttributes[.underlineStyle] = NSUnderlineStyle.single.rawValue
                ("サポートページを開く" as NSString).draw(in: label, withAttributes: linkAttributes)
                context.cgContext.setURL(link as CFURL, for: CGRect(x: label.minX, y: page.height - label.maxY,
                                                                  width: label.width, height: label.height))
            }
        }
    }
}
#endif
