import CoreImage
import SpriteKit
import UIKit

/// Loads bundled artwork as SpriteKit textures, and draws the small procedural pieces
/// (bubbles, planks, glows) that do not need painted art. Everything is cached.
enum Art {
    private static var images: [String: UIImage] = [:]
    private static var textures: [String: SKTexture] = [:]
    private static let context = CIContext(options: [.useSoftwareRenderer: false])

    static func hasAsset(_ name: String) -> Bool { UIImage(named: name) != nil }

    static func image(_ name: String) -> UIImage {
        if let cached = images[name] { return cached }
        let image = UIImage(named: name) ?? placeholder(for: name)
        images[name] = image
        return image
    }

    static func texture(_ name: String) -> SKTexture {
        if let cached = textures[name] { return cached }
        let texture = SKTexture(image: image(name))
        textures[name] = texture
        return texture
    }

    /// A washed-out copy of an image, used to show a world that has lost its colour.
    static func greyTexture(_ name: String) -> SKTexture {
        let key = "grey:" + name
        if let cached = textures[key] { return cached }
        let source = image(name)
        var texture = texture(name)
        if let cgImage = source.cgImage {
            let filter = CIFilter(name: "CIColorControls")
            filter?.setValue(CIImage(cgImage: cgImage), forKey: kCIInputImageKey)
            filter?.setValue(0.06, forKey: kCIInputSaturationKey)
            filter?.setValue(0.9, forKey: kCIInputContrastKey)
            filter?.setValue(-0.02, forKey: kCIInputBrightnessKey)
            if let output = filter?.outputImage,
               let rendered = context.createCGImage(output, from: CGRect(x: 0, y: 0, width: cgImage.width, height: cgImage.height)) {
                texture = SKTexture(cgImage: rendered)
            }
        }
        textures[key] = texture
        return texture
    }

    /// Stand-in art so the game still runs if an asset is missing from the bundle.
    private static func placeholder(for name: String) -> UIImage {
        if name.hasPrefix("bg_") {
            let size = CGSize(width: 768, height: 512)
            return UIGraphicsImageRenderer(size: size).image { context in
                let colours = [UIColor(hex: "#7FD6E8").cgColor, UIColor(hex: "#2E8FB0").cgColor] as CFArray
                let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colours, locations: [0, 1])!
                context.cgContext.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: 0, y: size.height), options: [])
            }
        }
        let glyphs: [(String, String)] = [
            ("otter", "🦦"), ("mosey", "🐋"), ("duo", "🦦"), ("guardian", "👾"), ("island", "🏝️"), ("crystal", "💎"),
            ("pearl", "⚪️"), ("egg", "🥚"), ("babydragon", "🐲"), ("chest", "🧰"), ("ring", "⭕️"), ("cliff", "🪨"),
            ("jar", "🫙"), ("friend", "🐠"), ("fg_", "🌿"), ("logo", "🌈"),
        ]
        let glyph = glyphs.first { name.hasPrefix($0.0) }?.1 ?? "⭐️"
        return emojiImage(glyph, size: 256)
    }

    // MARK: - Emoji

    private static func emojiImage(_ emoji: String, size: CGFloat) -> UIImage {
        let canvas = CGSize(width: size, height: size)
        return UIGraphicsImageRenderer(size: canvas).image { _ in
            let text = NSAttributedString(string: emoji, attributes: [.font: UIFont.systemFont(ofSize: size * 0.82)])
            let bounds = text.size()
            text.draw(at: CGPoint(x: (size - bounds.width) / 2, y: (size - bounds.height) / 2))
        }
    }

    static func emoji(_ emoji: String, size: CGFloat = 96) -> SKTexture {
        let key = "emoji:\(emoji):\(Int(size))"
        if let cached = textures[key] { return cached }
        let texture = SKTexture(image: emojiImage(emoji, size: size))
        textures[key] = texture
        return texture
    }

    // MARK: - Procedural pieces

    private static func drawn(_ key: String, size: CGSize, _ draw: @escaping (CGContext, CGRect) -> Void) -> SKTexture {
        if let cached = textures[key] { return cached }
        let image = UIGraphicsImageRenderer(size: size).image { draw($0.cgContext, CGRect(origin: .zero, size: size)) }
        let texture = SKTexture(image: image)
        textures[key] = texture
        return texture
    }

    /// A soft round glow, used for particles.
    static var glow: SKTexture {
        drawn("glow", size: CGSize(width: 48, height: 48)) { context, rect in
            let colours = [UIColor.white.cgColor, UIColor.white.withAlphaComponent(0).cgColor] as CFArray
            let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colours, locations: [0.1, 1])!
            context.drawRadialGradient(gradient, startCenter: rect.center, startRadius: 0, endCenter: rect.center, endRadius: 24, options: [])
        }
    }

    /// A small four-pointed sparkle.
    static var sparkle: SKTexture {
        drawn("sparkle", size: CGSize(width: 40, height: 40)) { context, rect in
            let c = rect.center
            let path = UIBezierPath()
            for index in 0..<8 {
                let angle = CGFloat(index) * .pi / 4
                let radius: CGFloat = index.isMultiple(of: 2) ? 19 : 5
                let point = CGPoint(x: c.x + cos(angle) * radius, y: c.y + sin(angle) * radius)
                index == 0 ? path.move(to: point) : path.addLine(to: point)
            }
            path.close()
            context.setFillColor(UIColor.white.cgColor)
            context.addPath(path.cgPath)
            context.fillPath()
        }
    }

    static var confettiPiece: SKTexture {
        drawn("confetti", size: CGSize(width: 14, height: 9)) { context, rect in
            context.setFillColor(UIColor.white.cgColor)
            context.addPath(UIBezierPath(roundedRect: rect, cornerRadius: 2).cgPath)
            context.fillPath()
        }
    }

    /// A glassy bubble with a rim and a highlight.
    static func bubble(tint: UIColor = UIColor(hex: "#BFF3FF")) -> SKTexture {
        drawn("bubble:\(tint.hexString)", size: CGSize(width: 256, height: 256)) { context, rect in
            let inner = rect.insetBy(dx: 8, dy: 8)
            let colours = [tint.withAlphaComponent(0.20).cgColor, tint.withAlphaComponent(0.55).cgColor] as CFArray
            let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colours, locations: [0.35, 1])!
            context.saveGState()
            context.addEllipse(in: inner)
            context.clip()
            context.drawRadialGradient(gradient, startCenter: rect.center, startRadius: 0, endCenter: rect.center, endRadius: 124, options: [])
            context.restoreGState()
            context.setStrokeColor(UIColor.white.withAlphaComponent(0.9).cgColor)
            context.setLineWidth(6)
            context.strokeEllipse(in: inner)
            context.setFillColor(UIColor.white.withAlphaComponent(0.85).cgColor)
            context.saveGState()
            context.translateBy(x: 82, y: 70)
            context.rotate(by: -0.6)
            context.fillEllipse(in: CGRect(x: -26, y: -11, width: 52, height: 22))
            context.restoreGState()
            context.fillEllipse(in: CGRect(x: 168, y: 176, width: 16, height: 16))
        }
    }

    static let rainbow: [UIColor] = ["#FF5B5B", "#FF9F40", "#FFD93D", "#55D66B", "#3DB8FF", "#8E6BFF"].map { UIColor(hex: $0) }

    /// A rounded plank striped with the six rainbow colours.
    static func rainbowPlank(size: CGSize) -> SKTexture {
        drawn("plank:\(Int(size.width))x\(Int(size.height))", size: size) { context, rect in
            context.addPath(UIBezierPath(roundedRect: rect.insetBy(dx: 1, dy: 1), cornerRadius: min(12, size.height / 3)).cgPath)
            context.clip()
            let stripe = rect.height / CGFloat(rainbow.count)
            for (index, colour) in rainbow.enumerated() {
                context.setFillColor(colour.cgColor)
                context.fill(CGRect(x: 0, y: CGFloat(index) * stripe, width: rect.width, height: stripe + 1))
            }
            context.setFillColor(UIColor.white.withAlphaComponent(0.25).cgColor)
            context.fill(CGRect(x: 0, y: 0, width: rect.width, height: rect.height * 0.18))
        }
    }

    /// A chunky rounded panel with an outline and a darker bottom edge, for signs, tiles and buttons.
    static func panel(size: CGSize, fill: UIColor, stroke: UIColor = UIColor(hex: "#0E3B43"), radius: CGFloat = 18, lineWidth: CGFloat = 4) -> SKTexture {
        let key = "panel:\(Int(size.width))x\(Int(size.height)):\(fill.hexString):\(stroke.hexString):\(Int(radius)):\(Int(lineWidth))"
        return drawn(key, size: size) { context, rect in
            let body = rect.insetBy(dx: lineWidth / 2, dy: lineWidth / 2)
            let path = UIBezierPath(roundedRect: body, cornerRadius: radius).cgPath
            context.addPath(path)
            context.setFillColor(fill.cgColor)
            context.fillPath()
            context.saveGState()
            context.addPath(path)
            context.clip()
            context.setFillColor(UIColor.black.withAlphaComponent(0.14).cgColor)
            context.fill(CGRect(x: 0, y: rect.height * 0.82, width: rect.width, height: rect.height * 0.18))
            context.setFillColor(UIColor.white.withAlphaComponent(0.22).cgColor)
            context.fill(CGRect(x: 0, y: 0, width: rect.width, height: rect.height * 0.16))
            context.restoreGState()
            context.addPath(path)
            context.setStrokeColor(stroke.cgColor)
            context.setLineWidth(lineWidth)
            context.strokePath()
        }
    }

    static func circle(diameter: CGFloat, fill: UIColor, stroke: UIColor = .white, lineWidth: CGFloat = 5) -> SKTexture {
        let key = "circle:\(Int(diameter)):\(fill.hexString):\(stroke.hexString):\(Int(lineWidth))"
        return drawn(key, size: CGSize(width: diameter, height: diameter)) { context, rect in
            let body = rect.insetBy(dx: lineWidth / 2, dy: lineWidth / 2)
            context.setFillColor(fill.cgColor)
            context.fillEllipse(in: body)
            context.setFillColor(UIColor.white.withAlphaComponent(0.28).cgColor)
            context.fillEllipse(in: CGRect(x: rect.width * 0.22, y: rect.height * 0.12, width: rect.width * 0.36, height: rect.height * 0.2))
            context.setStrokeColor(stroke.cgColor)
            context.setLineWidth(lineWidth)
            context.strokeEllipse(in: body)
        }
    }

    /// A small speech bubble with a tail, shown over whoever is talking.
    static var speechBubble: SKTexture {
        drawn("speechBubble", size: CGSize(width: 132, height: 110)) { context, rect in
            let body = CGRect(x: 5, y: 5, width: rect.width - 10, height: 78)
            let path = UIBezierPath(roundedRect: body, cornerRadius: 34)
            let tail = UIBezierPath()
            tail.move(to: CGPoint(x: 40, y: 78))
            tail.addLine(to: CGPoint(x: 34, y: 104))
            tail.addLine(to: CGPoint(x: 66, y: 80))
            tail.close()
            path.append(tail)
            context.setLineJoin(.round)
            context.addPath(path.cgPath)
            context.setStrokeColor(UIColor(hex: "#0E3B43").cgColor)
            context.setLineWidth(9)
            context.strokePath()
            context.addPath(path.cgPath)
            context.setFillColor(UIColor(hex: "#FFFDF3").cgColor)
            context.fillPath()
        }
    }

    /// A full rainbow arc, for bridge and island finales.
    static func rainbowArc(width: CGFloat) -> SKTexture {
        let size = CGSize(width: width, height: width / 2)
        return drawn("arc:\(Int(width))", size: size) { context, rect in
            let band = width * 0.035
            for (index, colour) in rainbow.enumerated() {
                let radius = width / 2 - band * (CGFloat(index) + 0.5)
                context.setStrokeColor(colour.withAlphaComponent(0.92).cgColor)
                context.setLineWidth(band + 0.5)
                context.addArc(center: CGPoint(x: rect.midX, y: rect.maxY), radius: radius, startAngle: .pi, endAngle: 2 * .pi, clockwise: false)
                context.strokePath()
            }
        }
    }
}

extension CGRect {
    var center: CGPoint { CGPoint(x: midX, y: midY) }
}

extension UIColor {
    convenience init(hex: String) {
        var value: UInt64 = 0
        Scanner(string: hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))).scanHexInt64(&value)
        self.init(red: CGFloat((value >> 16) & 0xFF) / 255, green: CGFloat((value >> 8) & 0xFF) / 255,
                  blue: CGFloat(value & 0xFF) / 255, alpha: 1)
    }

    var hexString: String {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        getRed(&r, green: &g, blue: &b, alpha: &a)
        return String(format: "%02X%02X%02X%02X", Int(r * 255), Int(g * 255), Int(b * 255), Int(a * 255))
    }

    func mixed(with other: UIColor, amount: CGFloat) -> UIColor {
        var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0
        var r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0, a2: CGFloat = 0
        getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
        other.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
        return UIColor(red: r1 + (r2 - r1) * amount, green: g1 + (g2 - g1) * amount, blue: b1 + (b2 - b1) * amount, alpha: a1 + (a2 - a1) * amount)
    }
}
