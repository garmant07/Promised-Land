import SpriteKit
import UIKit

/// Everything a tap on the world map can select.
nonisolated enum WorldHit: Hashable, Sendable {
    case character(String), journey(String), throne, library, story(String), landmark(String)
}

/// Shared helpers so every world-map layer offers taps the same way: its ground footprint
/// plus the visible part of its sprite, for `HitPicker`.
enum WorldHitBounds {
    private static var opaque: [ObjectIdentifier: CGRect] = [:]

    /// The visible part of a sprite's texture, in scene coordinates (y up).
    static func visibleFrame(of sprite: SKSpriteNode) -> CGRect {
        let frame = sprite.calculateAccumulatedFrame()
        guard let texture = sprite.texture else { return frame }
        let key = ObjectIdentifier(texture)
        let unit: CGRect
        if let cached = opaque[key] {
            unit = cached
        } else {
            unit = OpaqueBounds.unitRect(of: texture.cgImage())
            opaque[key] = unit
        }
        // Unit rect is y down from the top of the image; flip for SpriteKit, and mirror x if flipped.
        let x = sprite.xScale < 0 ? 1 - unit.maxX : unit.minX
        return CGRect(x: frame.minX + x * frame.width,
                      y: frame.maxY - unit.maxY * frame.height,
                      width: unit.width * frame.width, height: unit.height * frame.height)
    }

    /// True if a grid point is within a square footprint (with a little slack).
    static func onFootprint(_ g: CGPoint, x: Int, y: Int, size: Int, slack: CGFloat = 0.2) -> Bool {
        g.x >= CGFloat(x) - slack && g.x <= CGFloat(x + size) + slack &&
            g.y >= CGFloat(y) - slack && g.y <= CGFloat(y + size) + slack
    }
}

/// A tap is a touch with one finger that moves less than 10pt. It runs alongside panning,
/// so a pan simply makes it fail: panning never selects anything.
final class SlopTapRecognizer: UIGestureRecognizer {
    private var tracker = TapTracker()

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        guard (event.allTouches?.count ?? touches.count) == 1, let touch = touches.first else {
            state = .failed
            return
        }
        tracker.began(at: touch.location(in: view))
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
        guard let touch = touches.first else { return }
        tracker.moved(to: touch.location(in: view))
        if tracker.moved { state = .failed }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
        guard let touch = touches.first else { state = .failed; return }
        state = tracker.ended(at: touch.location(in: view)) ? .recognized : .failed
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) { state = .failed }

    override func reset() { tracker = TapTracker() }
}

/// A quick bounce and a soft glow at an object's foot, so you can see what you tapped.
enum TapFeedback {
    static func play(on node: SKNode, at ground: CGPoint, in parent: SKNode) {
        node.removeAction(forKey: "tapBounce")
        let up = SKAction.scale(by: 1.1, duration: 0.12)
        up.timingMode = .easeOut
        node.run(.sequence([up, up.reversed()]), withKey: "tapBounce")
        let glow = SKShapeNode(ellipseOf: CGSize(width: 60, height: 28))
        glow.fillColor = UIColor(red: 0.95, green: 0.84, blue: 0.55, alpha: 0.55)
        glow.strokeColor = .clear
        glow.position = ground
        glow.zPosition = node.zPosition - 0.01
        parent.addChild(glow)
        glow.run(.sequence([.group([.scale(to: 1.4, duration: 0.5), .fadeOut(withDuration: 0.5)]), .removeFromParent()]))
    }
}
