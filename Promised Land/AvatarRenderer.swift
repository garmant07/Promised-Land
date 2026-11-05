import SwiftUI

/// Draws an avatar from its layers, back to front: ground shadow, back hair, cloak (back),
/// body and skin, robe, sash, cloak (front), beard, front hair, head covering, held item.
/// Every layer is drawn on one 100 × 160 canvas with the feet at `footAnchor`, so layers
/// always line up. Chibi style, as in the char_ designs: big soft head, short vertical eyes,
/// no mouth, flat pastel colours, soft shading, no outlines.
nonisolated enum AvatarRenderer {
    static let canvas = CGSize(width: 100, height: 160)
    /// Where the feet stand (bottom centre).
    static let footAnchor = CGPoint(x: 50, y: 152)

    /// One drawn layer: its art-swap name (`av_<layer>_<option>`), main tint, and shapes.
    struct Layer {
        let name: String
        let option: String
        let tint: RGBValue
        var shapes: [(path: Path, colour: RGBValue)]
    }

    static func layers(_ a: AvatarConfig) -> [Layer] {
        let skin = RGBValue(hex: a.skin.hex)
        let hair = RGBValue(hex: a.hairColour.hex)
        let robe = RGBValue(hex: a.robeColour.hex)
        let cloak = RGBValue(hex: a.cloak == .redCape ? "#C2584A" : a.cloakColour.hex)
        let headCloth = RGBValue(hex: a.headColour.hex)
        let sandal = RGBValue(hex: a.sandals.hex)
        let gold = RGBValue(hex: "#E1B067"), wood = RGBValue(hex: "#8E6A4C"), cream = RGBValue(hex: "#F6EEDF")
        let eye = RGBValue(hex: "#4E3527"), blush = RGBValue(hex: "#E8A08A")
        let short = a.robe == .kneeTunic || a.robe == .sleevelessTunic
        let hem: CGFloat = short ? 126 : 147

        func ellipse(_ x: CGFloat, _ y: CGFloat, _ rx: CGFloat, _ ry: CGFloat) -> Path {
            Path(ellipseIn: CGRect(x: x - rx, y: y - ry, width: 2 * rx, height: 2 * ry))
        }
        func rect(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, _ r: CGFloat = 0) -> Path {
            Path(roundedRect: CGRect(x: x, y: y, width: w, height: h), cornerRadius: r)
        }
        func poly(_ pts: [(CGFloat, CGFloat)]) -> Path {
            Path { p in p.addLines(pts.map { CGPoint(x: $0.0, y: $0.1) }); p.closeSubpath() }
        }
        func capsule(from a: CGPoint, to b: CGPoint, width w: CGFloat) -> Path {
            Path { p in p.move(to: a); p.addLine(to: b) }
                .strokedPath(StrokeStyle(lineWidth: w, lineCap: .round))
        }

        var out: [Layer] = []

        // 1. Ground shadow.
        out.append(Layer(name: "shadow", option: "default", tint: RGBValue(hex: "#DCC193"),
                         shapes: [(ellipse(50, 151, 27, 5), RGBValue(hex: "#E6D3B0"))]))

        // 2. Back hair.
        var back: [(Path, RGBValue)] = []
        switch a.hair {
        case .longWavy:
            back.append((Path { p in
                p.move(to: CGPoint(x: 25, y: 42))
                p.addCurve(to: CGPoint(x: 28, y: 102), control1: CGPoint(x: 16, y: 66), control2: CGPoint(x: 22, y: 92))
                p.addQuadCurve(to: CGPoint(x: 72, y: 102), control: CGPoint(x: 50, y: 110))
                p.addCurve(to: CGPoint(x: 75, y: 42), control1: CGPoint(x: 78, y: 92), control2: CGPoint(x: 84, y: 66))
                p.closeSubpath()
            }, hair))
        case .longStraight:
            back.append((rect(24, 40, 52, 58, 14), hair))
        case .shortCurly:
            for i in 0..<9 {
                let t = Double(i) / 8 * .pi
                back.append((ellipse(50 - cos(t) * 26, 50 - sin(t) * 25 + 6, 9, 9), hair.shaded(0.92)))
            }
        case .bald, .baldWithSides:
            break
        }
        out.append(Layer(name: "hairBack", option: a.hair.rawValue, tint: hair, shapes: back))

        // 3. Cloak (back).
        var cloakBack: [(Path, RGBValue)] = []
        switch a.cloak {
        case .longCloak, .redCape, .coat:
            cloakBack.append((poly([(30, 80), (50, 74), (70, 80), (79, 146), (50, 150), (21, 146)]), cloak.shaded(0.82)))
        case .shoulderCloak:
            cloakBack.append((poly([(27, 82), (50, 72), (73, 82), (76, 108), (50, 113), (24, 108)]), cloak.shaded(0.82)))
        case .none:
            break
        }
        out.append(Layer(name: "cloakBack", option: a.cloak.rawValue, tint: cloak, shapes: cloakBack))

        // 4. Body and skin: neck, legs (short robes), sandalled feet.
        var body: [(Path, RGBValue)] = [(rect(43, 66, 14, 16, 5), skin.shaded(0.93))]
        if short {
            body.append((rect(40, 120, 8, 28, 4), skin))
            body.append((rect(52, 120, 8, 28, 4), skin.shaded(0.94)))
        }
        body.append((ellipse(43, 149, 8, 3.8), sandal))
        body.append((ellipse(57, 150, 8, 3.8), sandal.shaded(0.9)))
        if short {
            for y in [140.0, 144.0] {
                body.append((rect(39, CGFloat(y), 10, 1.6, 0.8), sandal))
                body.append((rect(51, CGFloat(y), 10, 1.6, 0.8), sandal))
            }
        }
        out.append(Layer(name: "body", option: a.skin.rawValue, tint: skin, shapes: body))

        // 5. Robe, with sleeves (or bare arms for the sleeveless tunic) and hands.
        var robeShapes: [(Path, RGBValue)] = []
        let top: CGFloat = 78
        let hemWidth: CGFloat = short ? 19 : 23
        robeShapes.append((Path { p in
            p.move(to: CGPoint(x: 33, y: top + 3))
            p.addQuadCurve(to: CGPoint(x: 67, y: top + 3), control: CGPoint(x: 50, y: top - 4))
            p.addLine(to: CGPoint(x: 50 + hemWidth, y: hem))
            p.addQuadCurve(to: CGPoint(x: 50 - hemWidth, y: hem), control: CGPoint(x: 50, y: hem + 5))
            p.closeSubpath()
        }, robe))
        // Soft shading on the right side.
        robeShapes.append((poly([(56, top + 1), (67, top + 3), (50 + hemWidth, hem), (58, hem + 2)]), robe.shaded(0.9)))
        // Neckline.
        robeShapes.append((poly([(45, top - 1), (55, top - 1), (50, top + 9)]), skin.shaded(0.93)))
        if a.robe == .robeWithPanel {
            robeShapes.append((poly([(46, top + 8), (54, top + 8), (57, hem), (43, hem)]), cream))
        }
        let sleeve = a.robe == .sleevelessTunic ? skin : (a.cloak == .coat ? cloak : robe)
        robeShapes.append((capsule(from: CGPoint(x: 36, y: 86), to: CGPoint(x: 44, y: 110), width: 11), sleeve))
        robeShapes.append((capsule(from: CGPoint(x: 64, y: 86), to: CGPoint(x: 67, y: 110), width: 11), sleeve.shaded(0.93)))
        if a.robe == .sleevelessTunic {
            robeShapes.append((rect(30.5, 90, 10, 3, 1.5), RGBValue(hex: "#A9784F")))
            robeShapes.append((rect(60, 90, 10, 3, 1.5), RGBValue(hex: "#A9784F")))
        }
        robeShapes.append((ellipse(46, 113, 5.2, 5), skin))
        robeShapes.append((ellipse(67, 114, 5, 5), skin.shaded(0.95)))
        out.append(Layer(name: "robe", option: a.robe.rawValue, tint: robe, shapes: robeShapes))

        // 6. Sash or trim.
        var sashShapes: [(Path, RGBValue)] = []
        switch a.sash {
        case .brownBelt:
            sashShapes.append((rect(33, 102, 34, 5, 2.5), RGBValue(hex: "#9A6A48")))
        case .goldTrim:
            sashShapes.append((poly([(44, top + 2), (47, top + 2), (45, hem), (42, hem)]), gold))
            sashShapes.append((poly([(53, top + 2), (56, top + 2), (58, hem), (55, hem)]), gold))
            sashShapes.append((rect(50 - hemWidth + 1, hem - 4, hemWidth * 2 - 2, 3, 1.5), gold))
        case .redSash:
            sashShapes.append((poly([(36, 82), (42, 80), (66, 108), (60, 112)]), RGBValue(hex: "#C8574A")))
        case .none:
            break
        }
        out.append(Layer(name: "sash", option: a.sash.rawValue, tint: RGBValue(hex: "#9A6A48"), shapes: sashShapes))

        // 7. Cloak (front).
        var cloakFront: [(Path, RGBValue)] = []
        switch a.cloak {
        case .longCloak, .coat:
            cloakFront.append((poly([(30, 81), (38, 81), (35, 147), (22, 145)]), cloak))
            cloakFront.append((poly([(62, 81), (70, 81), (78, 145), (65, 147)]), cloak.shaded(0.9)))
        case .shoulderCloak:
            cloakFront.append((Path { p in
                p.move(to: CGPoint(x: 29, y: 82))
                p.addQuadCurve(to: CGPoint(x: 71, y: 82), control: CGPoint(x: 50, y: 96))
                p.addQuadCurve(to: CGPoint(x: 66, y: 96), control: CGPoint(x: 72, y: 90))
                p.addQuadCurve(to: CGPoint(x: 34, y: 96), control: CGPoint(x: 50, y: 103))
                p.addQuadCurve(to: CGPoint(x: 29, y: 82), control: CGPoint(x: 28, y: 90))
            }, cloak))
        case .redCape:
            cloakFront.append((poly([(29, 81), (40, 80), (36, 100), (26, 98)]), cloak))
            cloakFront.append((poly([(60, 80), (71, 81), (74, 98), (64, 100)]), cloak.shaded(0.9)))
            cloakFront.append((ellipse(50, 82, 3, 3), gold))
        case .none:
            break
        }
        out.append(Layer(name: "cloakFront", option: a.cloak.rawValue, tint: cloak, shapes: cloakFront))

        // The head (with ears, eyes and cheeks) sits between the body and the beard.
        var head: [(Path, RGBValue)] = [
            (ellipse(25.5, 53, 4.5, 6.5), skin.shaded(0.94)), (ellipse(74.5, 53, 4.5, 6.5), skin.shaded(0.94)),
            (ellipse(50, 50, 25, 24), skin),
            (ellipse(57, 54, 18, 18).intersection(ellipse(50, 50, 25, 24)), skin.shaded(0.97)),
            (rect(39, 44, 5, 10, 2.5), eye), (rect(56, 44, 5, 10, 2.5), eye),
            (ellipse(37, 58, 4.5, 2.4), blush), (ellipse(63, 58, 4.5, 2.4), blush),
        ]
        if a.head == .veilWithWrap { head.removeLast(2) }
        out.append(Layer(name: "head", option: a.skin.rawValue, tint: skin, shapes: head))

        // 8. Beard.
        var beard: [(Path, RGBValue)] = []
        func beardPath(depth: CGFloat, width: CGFloat) -> Path {
            Path { p in
                p.move(to: CGPoint(x: 50 - width, y: 50))
                p.addQuadCurve(to: CGPoint(x: 50, y: 60 + depth), control: CGPoint(x: 50 - width, y: 58 + depth))
                p.addQuadCurve(to: CGPoint(x: 50 + width, y: 50), control: CGPoint(x: 50 + width, y: 58 + depth))
                p.addQuadCurve(to: CGPoint(x: 50, y: 61), control: CGPoint(x: 64, y: 63))
                p.addQuadCurve(to: CGPoint(x: 50 - width, y: 50), control: CGPoint(x: 36, y: 63))
            }
        }
        switch a.beard {
        case .short: beard.append((beardPath(depth: 14, width: 23), hair))
        case .full: beard.append((beardPath(depth: 22, width: 25), hair))
        case .longFlowing: beard.append((beardPath(depth: 42, width: 26), hair))
        case .none: break
        }
        if a.beard != .none {
            beard.append((Path { p in p.move(to: CGPoint(x: 42, y: 63)); p.addQuadCurve(to: CGPoint(x: 58, y: 63), control: CGPoint(x: 50, y: 67)) }
                .strokedPath(StrokeStyle(lineWidth: 1.6, lineCap: .round)), hair.shaded(0.85)))
        }
        out.append(Layer(name: "beard", option: a.beard.rawValue, tint: hair, shapes: beard))

        // 9. Front hair.
        var front: [(Path, RGBValue)] = []
        switch a.hair {
        case .shortCurly:
            for (x, y, r) in [(30.0, 40.0, 8.0), (38.0, 31.0, 9.0), (50.0, 27.0, 9.5), (62.0, 31.0, 9.0), (70.0, 40.0, 8.0), (44.0, 33.0, 7.0), (57.0, 33.0, 7.0)] {
                front.append((ellipse(x, y, r, r), hair))
            }
        case .longWavy, .longStraight:
            front.append((Path { p in
                p.move(to: CGPoint(x: 25, y: 50))
                p.addQuadCurve(to: CGPoint(x: 50, y: 24), control: CGPoint(x: 25, y: 24))
                p.addQuadCurve(to: CGPoint(x: 75, y: 50), control: CGPoint(x: 75, y: 24))
                p.addQuadCurve(to: CGPoint(x: 52, y: 36), control: CGPoint(x: 66, y: 36))
                p.addQuadCurve(to: CGPoint(x: 25, y: 50), control: CGPoint(x: 34, y: 34))
            }, hair))
            front.append((rect(24, 44, 6, 22, 3), hair))
            front.append((rect(70, 44, 6, 22, 3), hair.shaded(0.94)))
        case .baldWithSides:
            front.append((ellipse(27, 50, 4.5, 9), hair))
            front.append((ellipse(73, 50, 4.5, 9), hair))
        case .bald:
            break
        }
        if a.hair == .bald || a.hair == .baldWithSides {
            front.append((ellipse(43, 33, 8, 4), skin.shaded(1.12))) // a soft shine
        }
        out.append(Layer(name: "hairFront", option: a.hair.rawValue, tint: hair, shapes: front))

        // 10. Head covering.
        var cover: [(Path, RGBValue)] = []
        switch a.head {
        case .headband:
            cover.append((rect(25, 34, 50, 6, 3), headCloth.shaded(0.95)))
        case .veil, .veilWithWrap, .headdress:
            cover.append((Path { p in
                p.move(to: CGPoint(x: 21, y: 98))
                p.addLine(to: CGPoint(x: 22, y: 48))
                p.addQuadCurve(to: CGPoint(x: 50, y: 18), control: CGPoint(x: 22, y: 18))
                p.addQuadCurve(to: CGPoint(x: 78, y: 48), control: CGPoint(x: 78, y: 18))
                p.addLine(to: CGPoint(x: 79, y: 98))
                p.addQuadCurve(to: CGPoint(x: 69, y: 98), control: CGPoint(x: 74, y: 102))
                p.addLine(to: CGPoint(x: 69, y: 52))
                p.addQuadCurve(to: CGPoint(x: 50, y: 31), control: CGPoint(x: 68, y: 31))
                p.addQuadCurve(to: CGPoint(x: 31, y: 52), control: CGPoint(x: 32, y: 31))
                p.addLine(to: CGPoint(x: 31, y: 98))
                p.addQuadCurve(to: CGPoint(x: 21, y: 98), control: CGPoint(x: 26, y: 102))
            }, headCloth))
            cover.append((poly([(66, 40), (72, 46), (72, 96), (68, 96)]), headCloth.shaded(0.9)))
            if a.head == .veilWithWrap {
                cover.append((Path { p in
                    p.move(to: CGPoint(x: 30, y: 57))
                    p.addQuadCurve(to: CGPoint(x: 70, y: 57), control: CGPoint(x: 50, y: 66))
                    p.addLine(to: CGPoint(x: 70, y: 66))
                    p.addQuadCurve(to: CGPoint(x: 30, y: 66), control: CGPoint(x: 50, y: 82))
                    p.closeSubpath()
                }, headCloth.shaded(1.06)))
            }
            if a.head == .headdress {
                cover.append((rect(26, 30, 48, 5, 2.5), RGBValue(hex: "#8E603F")))
            }
        case .crown:
            cover.append((poly([(32, 30), (32, 16), (40, 23), (50, 12), (60, 23), (68, 16), (68, 30)]), gold))
            cover.append((ellipse(50, 24, 2.2, 2.2), RGBValue(hex: "#C8574A")))
            cover.append((ellipse(40, 26, 1.6, 1.6), RGBValue(hex: "#9DB8D2")))
            cover.append((ellipse(60, 26, 1.6, 1.6), RGBValue(hex: "#9DB8D2")))
        case .none:
            break
        }
        out.append(Layer(name: "covering", option: a.head.rawValue, tint: headCloth, shapes: cover))

        // 11. Held item.
        var item: [(Path, RGBValue)] = []
        switch a.item {
        case .staff:
            item.append((rect(68.5, 36, 3.6, 115, 1.8), wood))
            item.append((ellipse(70.3, 36, 3.4, 3.4), wood.shaded(0.85)))
        case .shepherdsCrook:
            item.append((rect(68.5, 46, 3.4, 105, 1.7), wood))
            item.append((Path { p in
                p.move(to: CGPoint(x: 70.2, y: 47)); p.addCurve(to: CGPoint(x: 79, y: 40), control1: CGPoint(x: 70, y: 32), control2: CGPoint(x: 80, y: 30))
            }.strokedPath(StrokeStyle(lineWidth: 3.4, lineCap: .round)), wood))
        case .scroll:
            item.append((rect(36, 106, 18, 9, 2), cream))
            item.append((ellipse(36, 110.5, 2.4, 4.8), RGBValue(hex: "#C99466")))
            item.append((ellipse(54, 110.5, 2.4, 4.8), RGBValue(hex: "#C99466")))
        case .book:
            item.append((rect(37, 102, 16, 20, 2), RGBValue(hex: "#A06A44")))
            item.append((rect(39, 104, 12, 16, 1.5), RGBValue(hex: "#B97E52")))
        case .wheatBundle:
            for dx in [-4.0, 0.0, 4.0] {
                item.append((rect(66 + dx, 84, 1.4, 30, 0.7), RGBValue(hex: "#C9A45A")))
                item.append((ellipse(66.7 + dx, 82, 2.4, 6), gold))
            }
        case .scepter:
            item.append((rect(68.5, 82, 3, 40, 1.5), gold))
            item.append((ellipse(70, 80, 4.2, 4.2), gold.shaded(1.1)))
        case .pouch:
            item.append((ellipse(66, 124, 6, 7), RGBValue(hex: "#A57A4E")))
            item.append((rect(62, 116, 8, 3, 1.5), RGBValue(hex: "#8A5A3C")))
        case .dove:
            item.append((ellipse(44, 104, 6, 3.6), RGBValue(r: 0.98, g: 0.97, b: 0.95)))
            item.append((poly([(41, 103), (46, 96), (48, 103)]), RGBValue(r: 0.94, g: 0.93, b: 0.9)))
            item.append((ellipse(50, 102, 2.2, 2), RGBValue(r: 0.98, g: 0.97, b: 0.95)))
        case .none:
            break
        }
        // The hand holding a staff, crook, wheat or sceptre is in front of it.
        if [.staff, .shepherdsCrook, .wheatBundle, .scepter].contains(a.item) {
            item.append((ellipse(67, 114, 5, 5), skin.shaded(0.95)))
        }
        if [.scroll, .book, .dove].contains(a.item) {
            item.append((ellipse(46, 113, 5.2, 5), skin))
        }
        out.append(Layer(name: "item", option: a.item.rawValue, tint: wood, shapes: item))
        return out
    }

    /// The bounds of everything drawn (for tests: it must stay inside the canvas).
    static func bounds(_ a: AvatarConfig) -> CGRect {
        layers(a).flatMap(\.shapes).map { $0.path.boundingRect }.filter { !$0.isEmpty }
            .reduce(CGRect.null) { $0.union($1) }
    }
}

/// The avatar as a view: used everywhere a character is shown (island, creator, Profile,
/// Friends, share images, the world map). Image assets named `av_<layer>_<option>` replace a
/// layer's code drawing (greyscale art is tinted with the layer's colour).
struct AvatarView: View {
    let config: AvatarConfig

    var body: some View {
        Canvas { c, size in
            let s = min(size.width / AvatarRenderer.canvas.width, size.height / AvatarRenderer.canvas.height)
            c.translateBy(x: (size.width - AvatarRenderer.canvas.width * s) / 2,
                          y: size.height - AvatarRenderer.canvas.height * s)
            c.scaleBy(x: s, y: s)
            for layer in AvatarRenderer.layers(config) {
                if let art = ArtAssets.image("av_\(layer.name)_\(layer.option)") {
                    var g = c
                    g.addFilter(.colorMultiply(layer.tint.color))
                    g.draw(Image(decorative: art.image, scale: 1), in: CGRect(origin: .zero, size: AvatarRenderer.canvas))
                    continue
                }
                for shape in layer.shapes { c.fill(shape.path, with: .color(shape.colour.color)) }
            }
        }
        .accessibilityHidden(true)
    }
}

#Preview("Presets") {
    ScrollView(.horizontal) {
        HStack {
            ForEach(["jesus", "mary", "david", "abraham", "sarah", "ruth", "daniel", "samson", "solomon", "paul", "john", "moses"], id: \.self) {
                AvatarView(config: AvatarPresets.config(for: $0)).frame(width: 90, height: 144)
            }
        }
    }
}

#if DEBUG
/// DEBUG: every character preset drawn by the renderer, beside its char_ art (`-avatarGallery`).
struct AvatarGallery: View {
    var body: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 150))], spacing: 10) {
                ForEach(PresetAccess.ids, id: \.self) { id in
                    VStack(spacing: 2) {
                        HStack(spacing: 2) {
                            AvatarView(config: AvatarPresets.config(for: id)).frame(width: 72, height: 115)
                            if ArtAssets.character(id) != nil {
                                Image("char_\(id)").resizable().scaledToFit().frame(width: 72, height: 115)
                            }
                        }
                        Text(id).font(.caption)
                    }
                }
            }
            .padding()
        }
        .background(Color.cream)
    }
}
#endif
