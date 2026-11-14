#if DEBUG
import SwiftUI
import UIKit
import ImageIO
import UniformTypeIdentifiers

/// Exports the current code-drawn island art as authoring references.
@MainActor
enum SpriteBaseExporter {
    private static let canvasPixels = CGSize(width: 256, height: 384)
    private static let groundPixels = CGPoint(x: 128, y: 300)
    private static let margin: CGFloat = 8
    private static let sourcePoints = CGSize(width: 1024, height: 1024)
    private static let sourceGround = CGPoint(x: 512, y: 512)
    private static let sourceU: CGFloat = 1

    private struct Exported {
        let name: String
        let kind: String
        let usedBy: String
        let growth: String
        let placement: String
        let scale: CGFloat
        let image: CGImage
        let renderedDirectly: Bool
    }

    static func export() {
        ArtAssets.forceCodeArt = true
        defer { ArtAssets.forceCodeArt = false }

        do {
            let folder = try outputFolder()
            let exports = makeExports()
            var borderFailures: [String] = []
            for item in exports {
                let url = folder.appendingPathComponent(item.name)
                try writePNG(item.image, to: url)
                if !borderIsTransparent(item.image) {
                    borderFailures.append(item.name)
                    print("SPRITE_BASES_BORDER_FAIL: \(item.name)")
                }
            }
            try writeCSV(exports, to: folder.appendingPathComponent("index.csv"))
            try writeContactSheet(exports, to: folder.appendingPathComponent("contact_sheet.png"))
            print("SPRITE_BASES_FOLDER: \(folder.path)")
            print("SPRITE_BASES_COUNT: \(exports.count)")
            let recentredCount = exports.filter { $0.placement == "recentred" }.count
            print("SPRITE_BASES_RECENTRED: \(recentredCount)")
            if borderFailures.isEmpty {
                print("SPRITE_BASES_BORDER_CHECK: PASS (\(exports.count) files)")
            } else {
                print("SPRITE_BASES_BORDER_CHECK: FAIL (\(borderFailures.count) files)")
            }
            let upFailures = upCheckFailures(exports)
            if upFailures.isEmpty {
                print("SPRITE_BASES_UP_CHECK: PASS (base_forest_round.png, base_house.png)")
            } else {
                for name in upFailures { print("SPRITE_BASES_UP_FAIL: \(name)") }
                print("SPRITE_BASES_UP_CHECK: FAIL (\(upFailures.count) files)")
            }
            if exports.allSatisfy(\.renderedDirectly) {
                print("SPRITE_BASES_SHARPNESS_CHECK: PASS (all files drawn directly at final scale)")
            } else {
                print("SPRITE_BASES_SHARPNESS_CHECK: FAIL")
            }
        } catch {
            print("SPRITE_BASES_ERROR: \(error.localizedDescription)")
        }
    }

    private static func outputFolder() throws -> URL {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let folder = documents.appendingPathComponent("SpriteBases", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        for url in try FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil) {
            try FileManager.default.removeItem(at: url)
        }
        return folder
    }

    private static func makeExports() -> [Exported] {
        var output: [Exported] = []
        for kind in PieceKind.allCases {
            let usedBy = books(using: kind)
            if kind.isGrowable {
                if let image = renderPiece(kind, growth: 14, cap: 14) {
                    output.append(imageRecord(image, name: "base_\(kind.rawValue)_full.png", kind: kind.rawValue,
                                              usedBy: usedBy, growth: "full"))
                }
                if let image = renderPiece(kind, growth: 1, cap: 14) {
                    output.append(imageRecord(image, name: "base_\(kind.rawValue)_start.png", kind: kind.rawValue,
                                              usedBy: usedBy, growth: "start"))
                }
            } else if let image = renderPiece(kind, growth: 0, cap: 1) {
                output.append(imageRecord(image, name: "base_\(kind.rawValue).png", kind: kind.rawValue,
                                          usedBy: usedBy, growth: "n/a"))
            }
        }
        for seed in 0..<3 {
            let name = ["round", "cedar", "palm"][seed]
            if let image = renderTree(seed: seed) {
                output.append(imageRecord(image, name: "base_forest_\(name).png", kind: "forest_\(name)",
                                          usedBy: "Forest", growth: "n/a"))
            }
        }
        for kind in ExtraKind.allCases {
            if let image = renderExtra(kind) {
                output.append(imageRecord(image, name: "base_extra_\(kind.rawValue).png", kind: "extra_\(kind.rawValue)", usedBy: "Edit mode", growth: "n/a"))
            }
        }
        for kind in [RewardKind.banner, .lantern, .fruitTree] {
            if let image = renderReward(kind) {
                output.append(imageRecord(image, name: "base_reward_\(kind.rawValue).png", kind: "reward_\(kind.rawValue)", usedBy: "Rewards", growth: "n/a"))
            }
        }
        if let image = renderCrowdPerson() {
            output.append(imageRecord(image, name: "base_crowd_person.png", kind: "crowd_person", usedBy: "Place crowd", growth: "n/a"))
        }
        if let image = renderVillager() {
            output.append(imageRecord(image, name: "base_villager_standing.png", kind: "villager_standing", usedBy: "Island life", growth: "n/a"))
        }
        return output
    }

    private static func imageRecord(_ image: (image: CGImage, scale: CGFloat, placement: String), name: String, kind: String,
                                    usedBy: String, growth: String) -> Exported {
        Exported(name: name, kind: kind, usedBy: usedBy, growth: growth, placement: image.placement,
                 scale: image.scale, image: image.image, renderedDirectly: true)
    }

    private static func renderPiece(_ kind: PieceKind, growth: CGFloat, cap: Int) -> (image: CGImage, scale: CGFloat, placement: String)? {
        let item = Island.Item(kind: .piece(kind), gx: 0, gy: 0, seed: 7, source: .feature(.library),
                               progress: 1, total: 1, level: 1, growth: growth, cap: cap, span: 3, facing: 1)
        return render { context, u in
            PlaceArt.draw(IsoPen(c: context, u: u), item: item, kind: kind, side: 1)
        }
    }

    private static func renderTree(seed: Int) -> (image: CGImage, scale: CGFloat, placement: String)? {
        render { context, u in PlaceArt.forestTree(IsoPen(c: context, u: u), seed: seed) }
    }

    private static func renderExtra(_ kind: ExtraKind) -> (image: CGImage, scale: CGFloat, placement: String)? {
        render { context, u in PlaceArt.extra(IsoPen(c: context, u: u), kind, seed: 7) }
    }

    private static func renderReward(_ kind: RewardKind) -> (image: CGImage, scale: CGFloat, placement: String)? {
        render { context, u in RewardArt.draw(IsoPen(c: context, u: u), kind, seed: 7) }
    }

    private static func renderCrowdPerson() -> (image: CGImage, scale: CGFloat, placement: String)? {
        render { context, u in PlaceArt.person(IsoPen(c: context, u: u), 0, 0, s: 1, seed: 7) }
    }

    private static func renderVillager() -> (image: CGImage, scale: CGFloat, placement: String)? {
        render { context, u in
            IslandLife.villager(&context, at: .zero, pose: Villager.Pose(point: .zero, pose: .idle, carrying: false, facingLeft: false),
                                robe: 0, produce: .bread, u: u, time: 0)
        }
    }

    private static func render(_ drawing: @escaping (inout GraphicsContext, CGFloat) -> Void) -> (image: CGImage, scale: CGFloat, placement: String)? {
        let canvas = Canvas { context, _ in
            var context = context
            context.translateBy(x: sourceGround.x, y: sourceGround.y)
            drawing(&context, sourceU)
        }
        let renderer = ImageRenderer(content: canvas.frame(width: sourcePoints.width, height: sourcePoints.height))
        renderer.scale = 2
        guard let source = renderer.cgImage else { return nil }
        let bounds = alphaBounds(source)
        guard !bounds.isNull, bounds.width > 0, bounds.height > 0 else { return nil }
        let ground = CGPoint(x: sourceGround.x * 2, y: sourceGround.y * 2)
        let left = ground.x - bounds.minX
        let right = bounds.maxX - ground.x
        let top = ground.y - bounds.minY
        let bottom = bounds.maxY - ground.y
        let limits = [
            left > 0 ? (groundPixels.x - margin) / left : .greatestFiniteMagnitude,
            right > 0 ? (canvasPixels.width - groundPixels.x - margin) / right : .greatestFiniteMagnitude,
            top > 0 ? (groundPixels.y - margin) / top : .greatestFiniteMagnitude,
            bottom > 0 ? (canvasPixels.height - groundPixels.y - margin) / bottom : .greatestFiniteMagnitude
        ]
        let groundScale = limits.min() ?? 0
        let isGroundPlacement = groundScale.isFinite && groundScale > 0
        var scale: CGFloat
        let placement: String
        var origin: CGPoint
        if isGroundPlacement {
            scale = groundScale
            placement = "ground"
            origin = groundPixels
        } else {
            scale = min((canvasPixels.width - 2 * margin) / bounds.width,
                        (canvasPixels.height - 2 * margin) / bounds.height)
            placement = "recentred"
            origin = CGPoint(x: canvasPixels.width / 2 - (bounds.midX - ground.x) * scale,
                             y: canvasPixels.height - margin - (bounds.maxY - ground.y) * scale)
        }
        func makeImage(at finalScale: CGFloat, origin: CGPoint) -> CGImage? {
            let canvas = Canvas { context, _ in
                var context = context
                context.translateBy(x: origin.x, y: origin.y)
                context.scaleBy(x: finalScale * 2, y: finalScale * 2)
                drawing(&context, sourceU)
            }
            let renderer = ImageRenderer(content: canvas.frame(width: canvasPixels.width, height: canvasPixels.height))
            renderer.scale = 1
            return renderer.cgImage
        }
        var image = makeImage(at: scale, origin: origin)
        for _ in 0..<20 {
            guard let current = image, !borderIsTransparent(current) else { break }
            scale *= 0.95
            if placement == "ground" {
                origin = groundPixels
            } else {
                origin = CGPoint(x: canvasPixels.width / 2 - (bounds.midX - ground.x) * scale,
                                 y: canvasPixels.height - margin - (bounds.maxY - ground.y) * scale)
            }
            image = makeImage(at: scale, origin: origin)
        }
        return image.map { ($0, scale, placement) }
    }

    private static func alphaBounds(_ image: CGImage) -> CGRect {
        guard let data = image.dataProvider?.data, let bytes = CFDataGetBytePtr(data) else { return .null }
        let alpha = image.alphaInfo == .first || image.alphaInfo == .premultipliedFirst ? 0 : 3
        var rect = CGRect.null
        for y in 0..<image.height {
            for x in 0..<image.width where bytes[y * image.bytesPerRow + x * 4 + alpha] > 0 {
                rect = rect.union(CGRect(x: x, y: y, width: 1, height: 1))
            }
        }
        return rect
    }

    private static func borderIsTransparent(_ image: CGImage) -> Bool {
        guard let data = image.dataProvider?.data, let bytes = CFDataGetBytePtr(data) else { return false }
        let alpha = image.alphaInfo == .first || image.alphaInfo == .premultipliedFirst ? 0 : 3
        for y in 0..<image.height where y < 4 || y >= image.height - 4 {
            for x in 0..<image.width where bytes[y * image.bytesPerRow + x * 4 + alpha] != 0 { return false }
        }
        for y in 4..<(image.height - 4) {
            for x in 0..<image.width where x < 4 || x >= image.width - 4 {
                if bytes[y * image.bytesPerRow + x * 4 + alpha] != 0 { return false }
            }
        }
        return true
    }

    private static func upCheckFailures(_ exports: [Exported]) -> [String] {
        ["base_forest_round.png", "base_house.png"].compactMap { name in
            guard let item = exports.first(where: { $0.name == name }),
                  let data = item.image.dataProvider?.data,
                  let bytes = CFDataGetBytePtr(data) else { return name }
            let alpha = item.image.alphaInfo == .first || item.image.alphaInfo == .premultipliedFirst ? 0 : 3
            var topmost = item.image.height
            var opaque = 0
            var aboveGround = 0
            for y in 0..<item.image.height {
                for x in 0..<item.image.width where bytes[y * item.image.bytesPerRow + x * 4 + alpha] > 0 {
                    topmost = min(topmost, y)
                    opaque += 1
                    if y < Int(groundPixels.y) { aboveGround += 1 }
                }
            }
            return topmost < Int(groundPixels.y) && aboveGround * 2 > opaque ? nil : name
        }
    }

    private static func books(using kind: PieceKind) -> String {
        PlaceData.all.filter { $0.pieces.contains { $0.kind == kind } }.map(\.bookID).joined(separator: " ")
    }

    private static func writePNG(_ image: CGImage, to url: URL) throws {
        guard let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else { throw CocoaError(.fileWriteUnknown) }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else { throw CocoaError(.fileWriteUnknown) }
    }

    private static func writeCSV(_ exports: [Exported], to url: URL) throws {
        var csv = "file name,piece kind,used by (books),scale,growth,placement\n"
        for item in exports {
            csv += [item.name, item.kind, item.usedBy, String(format: "%.5f", item.scale), item.growth, item.placement]
                .map { "\"\($0.replacingOccurrences(of: "\"", with: "\"\""))\"" }.joined(separator: ",") + "\n"
        }
        try csv.write(to: url, atomically: true, encoding: .utf8)
    }

    private static func writeContactSheet(_ exports: [Exported], to url: URL) throws {
        let columns = 4
        let cell = CGSize(width: 180, height: 230)
        let rows = Int(ceil(Double(exports.count) / Double(columns)))
        let image = UIGraphicsImageRenderer(size: CGSize(width: cell.width * CGFloat(columns), height: cell.height * CGFloat(rows))).image { _ in
            UIColor(red: 0.98, green: 0.94, blue: 0.84, alpha: 1).setFill()
            UIRectFill(CGRect(origin: .zero, size: CGSize(width: cell.width * CGFloat(columns), height: cell.height * CGFloat(rows))))
            for (index, item) in exports.enumerated() {
                let origin = CGPoint(x: CGFloat(index % columns) * cell.width, y: CGFloat(index / columns) * cell.height)
                let ratio = min((cell.width - 20) / CGFloat(item.image.width), 190 / CGFloat(item.image.height))
                let size = CGSize(width: CGFloat(item.image.width) * ratio, height: CGFloat(item.image.height) * ratio)
                UIGraphicsGetCurrentContext()?.draw(item.image, in: CGRect(x: origin.x + (cell.width - size.width) / 2,
                                                                            y: origin.y + 8 + (190 - size.height) / 2,
                                                                            width: size.width, height: size.height))
                (item.name as NSString).draw(in: CGRect(x: origin.x + 6, y: origin.y + 202, width: cell.width - 12, height: 22),
                                             withAttributes: [.font: UIFont.systemFont(ofSize: 10), .foregroundColor: UIColor.black])
            }
        }
        try writePNG(image.cgImage!, to: url)
    }
}
#endif
