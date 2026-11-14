import CoreGraphics
import Testing
@testable import Promised_Land

@MainActor @Suite(.serialized)
struct SpriteArtTests {
    @Test("Object sprites load at their authored canvas size and have measurable opaque widths")
    func objectSpritesLoadAndMeasureOpaqueWidth() throws {
        let house = try #require(ArtAssets.image("obj_house"))
        let tree = try #require(ArtAssets.image("obj_tree"))

        #expect(house.size == CGSize(width: 128, height: 192))
        #expect(tree.size == CGSize(width: 128, height: 192))
        #expect(ArtAssets.spriteMultipliers["obj_house"] == 0.5)
        #expect(ArtAssets.spriteMultipliers["obj_tree"] == 0.5)

        let houseOpaque = OpaqueBounds.unitRect(of: house.image)
        let treeOpaque = OpaqueBounds.unitRect(of: tree.image)
        #expect(abs(houseOpaque.width - 0.9375) < 0.0001)
        #expect(abs(treeOpaque.width - 0.78125) < 0.0001)
        #expect(houseOpaque.width > 0)
        #expect(treeOpaque.width > 0)
    }
}
