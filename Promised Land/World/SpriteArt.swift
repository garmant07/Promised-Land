import SpriteKit
import UIKit

/// Small shared textures (trees, rocks, clouds, birds, characters), drawn once in code.
enum SpriteArt {
    private static func texture(_ size: CGSize, scale: CGFloat = 2, draw: (CGContext) -> Void) -> SKTexture {
        let format = UIGraphicsImageRendererFormat()
        format.scale = scale
        let image = UIGraphicsImageRenderer(size: size, format: format).image { draw($0.cgContext) }
        return SKTexture(image: image)
    }

    private static func fill(_ c: CGContext, _ color: RGB, alpha: CGFloat = 1, _ rect: CGRect, ellipse: Bool = true) {
        c.setFillColor(color.cgColor(alpha: alpha))
        if ellipse { c.fillEllipse(in: rect) } else { c.fill(rect) }
    }

    // MARK: Decorations (anchor at bottom centre)

    static let olive = texture(CGSize(width: 34, height: 40)) { c in
        fill(c, .brown, alpha: 0.10, CGRect(x: 6, y: 33, width: 22, height: 7))
        c.setFillColor(RGB.trunk.cgColor)
        c.addPath(CGPath(roundedRect: CGRect(x: 14.5, y: 20, width: 5, height: 16), cornerWidth: 2.5, cornerHeight: 2.5, transform: nil))
        c.fillPath()
        fill(c, .oliveDeep, CGRect(x: 9, y: 6, width: 22, height: 17))
        fill(c, .olive, CGRect(x: 4, y: 3, width: 22, height: 18))
    }

    static let cypress = texture(CGSize(width: 20, height: 46)) { c in
        fill(c, .brown, alpha: 0.10, CGRect(x: 3, y: 40, width: 14, height: 6))
        fill(c, .oliveDeep, CGRect(x: 6, y: 4, width: 11, height: 40))
        fill(c, .olive, CGRect(x: 3, y: 2, width: 10, height: 40))
    }

    static let bush = texture(CGSize(width: 24, height: 16)) { c in
        fill(c, .brown, alpha: 0.08, CGRect(x: 2, y: 10, width: 20, height: 6))
        fill(c, .oliveDeep, CGRect(x: 8, y: 3, width: 14, height: 11))
        fill(c, .olive, CGRect(x: 2, y: 2, width: 14, height: 11))
    }

    static let rock = texture(CGSize(width: 22, height: 14)) { c in
        fill(c, .brown, alpha: 0.08, CGRect(x: 2, y: 8, width: 20, height: 6))
        fill(c, .stoneShade, CGRect(x: 6, y: 3, width: 14, height: 10))
        fill(c, .stoneLight, CGRect(x: 2, y: 1, width: 13, height: 10))
    }

    static let palm = texture(CGSize(width: 34, height: 40)) { c in
        fill(c, .brown, alpha: 0.10, CGRect(x: 8, y: 34, width: 18, height: 6))
        c.setFillColor(RGB.trunk.cgColor)
        c.addPath(CGPath(roundedRect: CGRect(x: 15.5, y: 12, width: 3.4, height: 25), cornerWidth: 1.7, cornerHeight: 1.7, transform: nil))
        c.fillPath()
        let leaf = RGB(hex: "#9DAE6C")
        for (x, y) in [(2.0, 10.0), (17.0, 10.0), (6.0, 5.0), (14.0, 5.0)] {
            fill(c, leaf, CGRect(x: x, y: y, width: 15, height: 6))
        }
    }

    static let glint = texture(CGSize(width: 16, height: 5)) { c in
        fill(c, .cream, alpha: 0.85, CGRect(x: 0, y: 0, width: 16, height: 5))
    }

    // MARK: Ambient

    static let cloud = texture(CGSize(width: 160, height: 70), scale: 1) { c in
        for (x, y, w, h) in [(10.0, 26.0, 70.0, 38.0), (45.0, 10.0, 70.0, 50.0), (85.0, 24.0, 66.0, 40.0), (30.0, 34.0, 100.0, 32.0)] {
            fill(c, .cream, alpha: 0.9, CGRect(x: x, y: y, width: w, height: h))
        }
    }

    static let birdUp = texture(CGSize(width: 16, height: 8)) { c in bird(c, up: true) }
    static let birdDown = texture(CGSize(width: 16, height: 8)) { c in bird(c, up: false) }

    private static func bird(_ c: CGContext, up: Bool) {
        c.setStrokeColor(RGB.brown.cgColor(alpha: 0.55))
        c.setLineWidth(1.6)
        c.setLineCap(.round)
        c.move(to: CGPoint(x: 1, y: up ? 1.5 : 5))
        c.addQuadCurve(to: CGPoint(x: 8, y: 5), control: CGPoint(x: 5, y: up ? 1 : 7))
        c.addQuadCurve(to: CGPoint(x: 15, y: up ? 1.5 : 5), control: CGPoint(x: 11, y: up ? 1 : 7))
        c.strokePath()
    }

    // MARK: Characters

    /// A simple robed figure, used when `char_<name>` isn't in the asset catalog.
    static func placeholderFigure(robe: RGB) -> SKTexture {
        texture(CGSize(width: 20, height: 36)) { c in
            fill(c, .brown, alpha: 0.12, CGRect(x: 3, y: 31, width: 14, height: 5))
            // Robe
            let body = CGMutablePath()
            body.move(to: CGPoint(x: 10, y: 11))
            body.addCurve(to: CGPoint(x: 17, y: 32), control1: CGPoint(x: 15, y: 13), control2: CGPoint(x: 17, y: 24))
            body.addLine(to: CGPoint(x: 3, y: 32))
            body.addCurve(to: CGPoint(x: 10, y: 11), control1: CGPoint(x: 3, y: 24), control2: CGPoint(x: 5, y: 13))
            c.addPath(body)
            c.setFillColor(robe.cgColor)
            c.fillPath()
            // Shaded right side
            c.saveGState()
            c.addPath(body); c.clip()
            fill(c, robe.shifted(-0.08), CGRect(x: 10, y: 10, width: 10, height: 24), ellipse: false)
            c.restoreGState()
            // Sash
            fill(c, .cream, alpha: 0.7, CGRect(x: 5.5, y: 19, width: 9, height: 2.4), ellipse: false)
            // Head and headcloth
            fill(c, RGB(hex: "#E7C3A0"), CGRect(x: 5.5, y: 3, width: 9, height: 9))
            fill(c, .cream, CGRect(x: 4.5, y: 1.5, width: 11, height: 6))
        }
    }

    /// A rounded speech bubble: the speaker's name, then their line in serif.
    static func speechBubble(line: String, name: String) -> SKTexture {
        let body = UIFont.systemFont(ofSize: 12, weight: .regular)
        let serif = body.fontDescriptor.withDesign(.serif).map { UIFont(descriptor: $0, size: 12) } ?? body
        let text = NSMutableAttributedString(string: name + "\n", attributes: [
            .font: UIFont.systemFont(ofSize: 12, weight: .bold),
            .foregroundColor: UIColor(red: 0.89, green: 0.60, blue: 0.49, alpha: 1),
        ])
        text.append(NSAttributedString(string: "\u{201C}\(line)\u{201D}", attributes: [
            .font: serif,
            .foregroundColor: UIColor(red: 0.18, green: 0.14, blue: 0.09, alpha: 1),
        ]))
        return bubble(text, width: 190)
    }

    private static func bubble(_ text: NSAttributedString, width: CGFloat) -> SKTexture {
        let inner = text.boundingRect(with: CGSize(width: width - 24, height: 400), options: [.usesLineFragmentOrigin], context: nil)
        let size = CGSize(width: width, height: ceil(inner.height) + 20 + 8)
        return texture(size, scale: 3) { c in
            let bubble = UIBezierPath(roundedRect: CGRect(x: 0, y: 0, width: size.width, height: size.height - 8), cornerRadius: 14)
            bubble.move(to: CGPoint(x: size.width / 2 - 7, y: size.height - 8))
            bubble.addLine(to: CGPoint(x: size.width / 2, y: size.height))
            bubble.addLine(to: CGPoint(x: size.width / 2 + 7, y: size.height - 8))
            UIColor(red: 0.98, green: 0.94, blue: 0.87, alpha: 0.97).setFill()
            bubble.fill()
            UIGraphicsPushContext(c)
            text.draw(with: CGRect(x: 12, y: 10, width: width - 24, height: inner.height + 2), options: [.usesLineFragmentOrigin], context: nil)
            UIGraphicsPopContext()
        }
    }
}
