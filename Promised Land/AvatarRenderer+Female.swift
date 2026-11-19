import SwiftUI

extension AvatarRenderer {
    /// Female geometry keeps the shared 100 × 160 canvas and foot anchor, while narrowing the
    /// shoulders and giving both supported robes a wider hem.
    static func femaleLayers(_ a: AvatarConfig) -> [Layer] {
        let skin = RGBValue(hex: a.skin.hex)
        let hair = RGBValue(hex: a.hairColour.hex)
        let robe = RGBValue(hex: a.robeColour.hex)
        let cloak = RGBValue(hex: a.cloak == .redCape ? "#C2584A" : a.cloakColour.hex)
        let headCloth = RGBValue(hex: a.headColour.hex)
        let sandal = RGBValue(hex: a.sandals.hex)
        let gold = RGBValue(hex: "#E1B067")
        let wood = RGBValue(hex: "#8E6A4C")
        let cream = RGBValue(hex: "#F6EEDF")
        let eye = RGBValue(hex: "#4E3527")
        let blush = RGBValue(hex: "#E8A08A")
        let short = a.robe == .kneeTunic || a.robe == .sleevelessTunic
        let hem: CGFloat = short ? 126 : 147
        let hemWidth: CGFloat = short ? 22 : 28

        func ellipse(_ x: CGFloat, _ y: CGFloat, _ rx: CGFloat, _ ry: CGFloat) -> Path {
            Path(ellipseIn: CGRect(x: x - rx, y: y - ry, width: 2 * rx, height: 2 * ry))
        }
        func rect(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, _ r: CGFloat = 0) -> Path {
            Path(roundedRect: CGRect(x: x, y: y, width: w, height: h), cornerRadius: r)
        }
        func poly(_ points: [(CGFloat, CGFloat)]) -> Path {
            Path { path in
                path.addLines(points.map { CGPoint(x: $0.0, y: $0.1) })
                path.closeSubpath()
            }
        }
        func capsule(from start: CGPoint, to end: CGPoint, width: CGFloat) -> Path {
            Path { path in
                path.move(to: start)
                path.addLine(to: end)
            }
            .strokedPath(StrokeStyle(lineWidth: width, lineCap: .round))
        }

        var layers: [Layer] = []
        layers.append(Layer(name: "shadow", option: "default", tint: RGBValue(hex: "#DCC193"),
                            shapes: [(ellipse(50, 151, 27, 5), RGBValue(hex: "#E6D3B0"))]))

        var backHair: [(Path, RGBValue)] = []
        switch a.hair {
        case .longWavy:
            backHair.append((Path { path in
                path.move(to: CGPoint(x: 26, y: 42))
                path.addCurve(to: CGPoint(x: 29, y: 96), control1: CGPoint(x: 18, y: 66), control2: CGPoint(x: 24, y: 88))
                path.addQuadCurve(to: CGPoint(x: 71, y: 96), control: CGPoint(x: 50, y: 105))
                path.addCurve(to: CGPoint(x: 74, y: 42), control1: CGPoint(x: 76, y: 88), control2: CGPoint(x: 82, y: 66))
                path.closeSubpath()
            }, hair))
        case .longStraight:
            backHair.append((rect(25, 40, 50, 56, 14), hair))
        case .shortCurly:
            for index in 0..<9 {
                let angle = Double(index) / 8 * .pi
                backHair.append((ellipse(50 - cos(angle) * 26, 50 - sin(angle) * 25 + 6, 9, 9), hair.shaded(0.92)))
            }
        case .braid:
            backHair.append((rect(27, 40, 46, 39, 14), hair))
        case .bun:
            backHair.append((ellipse(65, 29, 12, 10), hair.shaded(0.94)))
        case .bald, .baldWithSides:
            break
        }
        layers.append(Layer(name: "hairBack", option: a.hair.rawValue, tint: hair, shapes: backHair))

        var cloakBack: [(Path, RGBValue)] = []
        switch a.cloak {
        case .longCloak, .redCape, .coat:
            cloakBack.append((poly([(32, 81), (50, 75), (68, 81), (76, 146), (50, 150), (24, 146)]), cloak.shaded(0.82)))
        case .shoulderCloak:
            cloakBack.append((poly([(29, 83), (50, 74), (71, 83), (74, 108), (50, 113), (26, 108)]), cloak.shaded(0.82)))
        case .none:
            break
        }
        layers.append(Layer(name: "cloakBack", option: a.cloak.rawValue, tint: cloak, shapes: cloakBack))

        var body: [(Path, RGBValue)] = [(rect(44, 66, 12, 16, 5), skin.shaded(0.93))]
        if short {
            body.append((rect(41, 120, 8, 28, 4), skin))
            body.append((rect(51, 120, 8, 28, 4), skin.shaded(0.94)))
        }
        body.append((ellipse(43, 149, 8, 3.8), sandal))
        body.append((ellipse(57, 150, 8, 3.8), sandal.shaded(0.9)))
        if short {
            for y in [140.0, 144.0] {
                body.append((rect(40, CGFloat(y), 10, 1.6, 0.8), sandal))
                body.append((rect(50, CGFloat(y), 10, 1.6, 0.8), sandal))
            }
        }
        layers.append(Layer(name: "body", option: a.skin.rawValue, tint: skin, shapes: body))

        var robeShapes: [(Path, RGBValue)] = []
        let top: CGFloat = 78
        robeShapes.append((Path { path in
            path.move(to: CGPoint(x: 35, y: top + 3))
            path.addQuadCurve(to: CGPoint(x: 65, y: top + 3), control: CGPoint(x: 50, y: top - 4))
            path.addLine(to: CGPoint(x: 50 + hemWidth, y: hem))
            path.addQuadCurve(to: CGPoint(x: 50 - hemWidth, y: hem), control: CGPoint(x: 50, y: hem + 5))
            path.closeSubpath()
        }, robe))
        robeShapes.append((poly([(55, top + 1), (65, top + 3), (50 + hemWidth, hem), (57, hem + 2)]), robe.shaded(0.9)))
        robeShapes.append((poly([(45, top - 1), (55, top - 1), (50, top + 9)]), skin.shaded(0.93)))
        if a.robe == .robeWithPanel {
            robeShapes.append((poly([(46, top + 8), (54, top + 8), (57, hem), (43, hem)]), cream))
        }
        let sleeve = a.robe == .sleevelessTunic ? skin : (a.cloak == .coat ? cloak : robe)
        robeShapes.append((capsule(from: CGPoint(x: 37, y: 86), to: CGPoint(x: 43, y: 110), width: 10), sleeve))
        robeShapes.append((capsule(from: CGPoint(x: 63, y: 86), to: CGPoint(x: 67, y: 110), width: 10), sleeve.shaded(0.93)))
        if a.robe == .sleevelessTunic {
            robeShapes.append((rect(32, 90, 9, 3, 1.5), RGBValue(hex: "#A9784F")))
            robeShapes.append((rect(59, 90, 9, 3, 1.5), RGBValue(hex: "#A9784F")))
        }
        robeShapes.append((ellipse(45, 113, 5, 5), skin))
        robeShapes.append((ellipse(65, 114, 5, 5), skin.shaded(0.95)))
        layers.append(Layer(name: "robe", option: a.robe.rawValue, tint: robe, shapes: robeShapes))

        var sashShapes: [(Path, RGBValue)] = []
        switch a.sash {
        case .brownBelt:
            sashShapes.append((rect(35, 102, 30, 5, 2.5), RGBValue(hex: "#9A6A48")))
        case .goldTrim:
            sashShapes.append((poly([(45, top + 2), (47.5, top + 2), (45, hem), (42.5, hem)]), gold))
            sashShapes.append((poly([(52.5, top + 2), (55, top + 2), (57.5, hem), (55, hem)]), gold))
            sashShapes.append((rect(50 - hemWidth + 1, hem - 4, hemWidth * 2 - 2, 3, 1.5), gold))
        case .redSash:
            sashShapes.append((poly([(37, 82), (43, 80), (64, 108), (59, 112)]), RGBValue(hex: "#C8574A")))
        case .none:
            break
        }
        layers.append(Layer(name: "sash", option: a.sash.rawValue, tint: RGBValue(hex: "#9A6A48"), shapes: sashShapes))

        var cloakFront: [(Path, RGBValue)] = []
        switch a.cloak {
        case .longCloak, .coat:
            cloakFront.append((poly([(32, 81), (39, 81), (36, 147), (25, 145)]), cloak))
            cloakFront.append((poly([(61, 81), (68, 81), (75, 145), (64, 147)]), cloak.shaded(0.9)))
        case .shoulderCloak:
            cloakFront.append((Path { path in
                path.move(to: CGPoint(x: 31, y: 82))
                path.addQuadCurve(to: CGPoint(x: 69, y: 82), control: CGPoint(x: 50, y: 96))
                path.addQuadCurve(to: CGPoint(x: 65, y: 96), control: CGPoint(x: 70, y: 90))
                path.addQuadCurve(to: CGPoint(x: 35, y: 96), control: CGPoint(x: 50, y: 103))
                path.addQuadCurve(to: CGPoint(x: 31, y: 82), control: CGPoint(x: 30, y: 90))
            }, cloak))
        case .redCape:
            cloakFront.append((poly([(31, 81), (40, 80), (36, 100), (28, 98)]), cloak))
            cloakFront.append((poly([(60, 80), (69, 81), (72, 98), (64, 100)]), cloak.shaded(0.9)))
            cloakFront.append((ellipse(50, 82, 3, 3), gold))
        case .none:
            break
        }
        layers.append(Layer(name: "cloakFront", option: a.cloak.rawValue, tint: cloak, shapes: cloakFront))

        var head: [(Path, RGBValue)] = [
            (ellipse(25.5, 53, 4.5, 6.5), skin.shaded(0.94)),
            (ellipse(74.5, 53, 4.5, 6.5), skin.shaded(0.94)),
            (ellipse(50, 50, 25, 24), skin),
            (ellipse(57, 54, 18, 18).intersection(ellipse(50, 50, 25, 24)), skin.shaded(0.97)),
            (rect(39, 44, 5, 10, 2.5), eye),
            (rect(56, 44, 5, 10, 2.5), eye),
            (ellipse(37, 58, 4.5, 2.4), blush),
            (ellipse(63, 58, 4.5, 2.4), blush)
        ]
        if a.head == .veilWithWrap { head.removeLast(2) }
        layers.append(Layer(name: "head", option: a.skin.rawValue, tint: skin, shapes: head))

        layers.append(Layer(name: "beard", option: a.beard.rawValue, tint: hair, shapes: []))

        var frontHair: [(Path, RGBValue)] = []
        switch a.hair {
        case .shortCurly:
            for (x, y, radius) in [(30.0, 40.0, 8.0), (38.0, 31.0, 9.0), (50.0, 27.0, 9.5), (62.0, 31.0, 9.0), (70.0, 40.0, 8.0), (44.0, 33.0, 7.0), (57.0, 33.0, 7.0)] {
                frontHair.append((ellipse(x, y, radius, radius), hair))
            }
        case .longWavy, .longStraight, .braid, .bun:
            frontHair.append((Path { path in
                path.move(to: CGPoint(x: 25, y: 50))
                path.addQuadCurve(to: CGPoint(x: 50, y: 24), control: CGPoint(x: 25, y: 24))
                path.addQuadCurve(to: CGPoint(x: 75, y: 50), control: CGPoint(x: 75, y: 24))
                path.addQuadCurve(to: CGPoint(x: 52, y: 36), control: CGPoint(x: 66, y: 36))
                path.addQuadCurve(to: CGPoint(x: 25, y: 50), control: CGPoint(x: 34, y: 34))
            }, hair))
            frontHair.append((rect(24, 44, 6, 22, 3), hair))
            frontHair.append((rect(70, 44, 6, 22, 3), hair.shaded(0.94)))
            if a.hair == .braid {
                frontHair.append((capsule(from: CGPoint(x: 69, y: 58), to: CGPoint(x: 68, y: 92), width: 9), hair.shaded(0.93)))
                frontHair.append((capsule(from: CGPoint(x: 68, y: 91), to: CGPoint(x: 67, y: 112), width: 8), hair))
            }
        case .baldWithSides:
            frontHair.append((ellipse(28, 50, 4.5, 9), hair))
            frontHair.append((ellipse(72, 50, 4.5, 9), hair))
        case .bald:
            break
        }
        layers.append(Layer(name: "hairFront", option: a.hair.rawValue, tint: hair, shapes: frontHair))

        var cover: [(Path, RGBValue)] = []
        switch a.head {
        case .veil, .veilWithWrap:
            cover.append((Path { path in
                path.move(to: CGPoint(x: 23, y: 98))
                path.addLine(to: CGPoint(x: 24, y: 48))
                path.addQuadCurve(to: CGPoint(x: 50, y: 19), control: CGPoint(x: 24, y: 19))
                path.addQuadCurve(to: CGPoint(x: 76, y: 48), control: CGPoint(x: 76, y: 19))
                path.addLine(to: CGPoint(x: 77, y: 98))
                path.addQuadCurve(to: CGPoint(x: 68, y: 98), control: CGPoint(x: 72, y: 102))
                path.addLine(to: CGPoint(x: 68, y: 52))
                path.addQuadCurve(to: CGPoint(x: 50, y: 31), control: CGPoint(x: 67, y: 31))
                path.addQuadCurve(to: CGPoint(x: 32, y: 52), control: CGPoint(x: 33, y: 31))
                path.addLine(to: CGPoint(x: 32, y: 98))
                path.addQuadCurve(to: CGPoint(x: 23, y: 98), control: CGPoint(x: 27, y: 102))
            }, headCloth))
            cover.append((poly([(65, 40), (71, 46), (71, 96), (68, 96)]), headCloth.shaded(0.9)))
            if a.head == .veilWithWrap {
                cover.append((Path { path in
                    path.move(to: CGPoint(x: 30, y: 57))
                    path.addQuadCurve(to: CGPoint(x: 70, y: 57), control: CGPoint(x: 50, y: 66))
                    path.addLine(to: CGPoint(x: 70, y: 66))
                    path.addQuadCurve(to: CGPoint(x: 30, y: 66), control: CGPoint(x: 50, y: 82))
                    path.closeSubpath()
                }, headCloth.shaded(1.06)))
            }
        case .queenCrown:
            cover.append((Path { path in
                path.move(to: CGPoint(x: 34, y: 31))
                path.addQuadCurve(to: CGPoint(x: 66, y: 31), control: CGPoint(x: 50, y: 35))
                path.addLine(to: CGPoint(x: 66, y: 27))
                path.addLine(to: CGPoint(x: 60, y: 21))
                path.addLine(to: CGPoint(x: 56, y: 28))
                path.addLine(to: CGPoint(x: 50, y: 18))
                path.addLine(to: CGPoint(x: 44, y: 28))
                path.addLine(to: CGPoint(x: 40, y: 21))
                path.addLine(to: CGPoint(x: 34, y: 27))
                path.closeSubpath()
            }, gold))
            cover.append((ellipse(50, 22, 2, 2), RGBValue(hex: "#C8574A")))
        case .none, .headband, .headdress, .crown:
            break
        }
        layers.append(Layer(name: "covering", option: a.head.rawValue, tint: headCloth, shapes: cover))

        var item: [(Path, RGBValue)] = []
        switch a.item {
        case .staff:
            item.append((rect(67, 36, 3.6, 115, 1.8), wood))
            item.append((ellipse(68.8, 36, 3.4, 3.4), wood.shaded(0.85)))
        case .shepherdsCrook:
            item.append((rect(67, 46, 3.4, 105, 1.7), wood))
            item.append((Path { path in
                path.move(to: CGPoint(x: 68.7, y: 47))
                path.addCurve(to: CGPoint(x: 77, y: 40), control1: CGPoint(x: 68.5, y: 32), control2: CGPoint(x: 78, y: 30))
            }.strokedPath(StrokeStyle(lineWidth: 3.4, lineCap: .round)), wood))
        case .scroll:
            item.append((rect(37, 106, 18, 9, 2), cream))
            item.append((ellipse(37, 110.5, 2.4, 4.8), RGBValue(hex: "#C99466")))
            item.append((ellipse(55, 110.5, 2.4, 4.8), RGBValue(hex: "#C99466")))
        case .book:
            item.append((rect(38, 102, 16, 20, 2), RGBValue(hex: "#A06A44")))
            item.append((rect(40, 104, 12, 16, 1.5), RGBValue(hex: "#B97E52")))
        case .wheatBundle:
            for delta in [-4.0, 0.0, 4.0] {
                item.append((rect(65 + delta, 84, 1.4, 30, 0.7), RGBValue(hex: "#C9A45A")))
                item.append((ellipse(65.7 + delta, 82, 2.4, 6), gold))
            }
        case .scepter:
            item.append((rect(67, 82, 3, 40, 1.5), gold))
            item.append((ellipse(68.5, 80, 4.2, 4.2), gold.shaded(1.1)))
        case .pouch:
            item.append((ellipse(65, 124, 6, 7), RGBValue(hex: "#A57A4E")))
            item.append((rect(61, 116, 8, 3, 1.5), RGBValue(hex: "#8A5A3C")))
        case .dove:
            item.append((ellipse(44, 104, 6, 3.6), RGBValue(r: 0.98, g: 0.97, b: 0.95)))
            item.append((poly([(41, 103), (46, 96), (48, 103)]), RGBValue(r: 0.94, g: 0.93, b: 0.9)))
            item.append((ellipse(50, 102, 2.2, 2), RGBValue(r: 0.98, g: 0.97, b: 0.95)))
        case .none:
            break
        }
        if [.staff, .shepherdsCrook, .wheatBundle, .scepter].contains(a.item) {
            item.append((ellipse(65, 114, 5, 5), skin.shaded(0.95)))
        }
        if [.scroll, .book, .dove].contains(a.item) {
            item.append((ellipse(45, 113, 5, 5), skin))
        }
        layers.append(Layer(name: "item", option: a.item.rawValue, tint: wood, shapes: item))
        return layers
    }
}

#Preview("Female avatar options") {
    VStack(spacing: 12) {
        HStack {
            AvatarView(config: AvatarSexRules.defaults(for: .male))
            AvatarView(config: AvatarSexRules.defaults(for: .female))
        }
        .frame(width: 180, height: 180)

        ForEach(["mary", "ruth", "sarah", "david", "moses"], id: \.self) { id in
            HStack {
                Text(id.capitalized).frame(width: 70, alignment: .leading)
                AvatarView(config: AvatarPresets.config(for: id))
            }
            .frame(height: 120)
        }
    }
    .padding()
    .background(Color.cream)
}
