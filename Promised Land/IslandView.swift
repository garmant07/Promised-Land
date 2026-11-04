import SwiftUI

/// The island, filling the screen and set in the sea: pinch to zoom, drag to pan, twist (or
/// use the turn buttons) to rotate it a quarter turn, tap an object to inspect it. Your
/// character strolls around on it at a constant size, so it looks smaller as the island grows.
struct PlatformScene: View {
    let avatar: Avatar
    let island: Island
    /// Items from this index onward build in when `revealID` changes.
    var revealFrom = 0
    var revealID = 0
    /// Room kept clear of the island (for the status pill and the bottom bar).
    var insets = EdgeInsets()
    var selected: Binding<Int?> = .constant(nil)
    /// Buildings that just grew bounce when `growID` changes.
    var grown: Set<Int> = []
    var growID = 0
    /// Your own island keeps its camera (zoom, pan, turn) between launches and shows the
    /// turn and "Find me" buttons. Friends' islands don't.
    var persistsCamera = false
    /// Edit mode: plots can be dragged and turned (see `IslandEditing`). Nil = not editing.
    var editing: IslandEditing? = nil
    /// Holding a building for half a second (outside edit mode) reports its index.
    var onLongPress: ((Int) -> Void)? = nil
    /// Unlocked Bible characters strolling around their books' plots.
    var characters: [IslandCharacter] = []
    /// "Read their story" in a character's speech bubble.
    var onReadStory: ((ChapterRef) -> Void)? = nil
    /// Visiting a building: your character walks to its door while the camera eases in,
    /// then `onArrived` is called. Setting it back to nil restores the camera.
    var visit: Int? = nil
    var onArrived: ((Int) -> Void)? = nil
    /// Called with the tapped item's index (nil for empty ground). Nil callback = read-only.
    var onTap: ((Int?) -> Void)? = nil

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // Camera
    @State private var zoom: CGFloat = 1
    @State private var zoomStart: CGFloat = 1
    @State private var pan: CGSize = .zero
    @State private var panStart: CGSize = .zero
    @State private var isPanning = false
    /// Set while a pinch or twist is under way, so lifting the fingers never selects.
    @State private var pinched = false
    /// Quarter turns: `angle` animates towards `quarter`.
    @State private var quarter = 0
    @State private var angle: CGFloat = 0
    @State private var cameraLoaded = false
    // Touches: long press, and dragging plots in edit mode.
    @State private var touchID = 0
    @State private var touchDown = false
    @State private var longPressed = false
    @State private var draggingPlot: (key: String, start: CGPoint)?
    /// The character talking, and since when (they stand still while talking).
    @State private var speaking: (id: String, since: Date)?
    /// The camera before a visit, to come back to.
    @State private var cameraBeforeVisit: (zoom: CGFloat, pan: CGSize)?
    @State private var walkToken = 0
    /// Bumped to start (or cancel) a camera glide.
    @State private var cameraGlide = 0

    // Character
    @State private var spot = CGPoint(x: 1, y: 1)
    @State private var walkFrom = CGPoint(x: 1, y: 1)
    @State private var walkStart = Date.distantPast
    @State private var walkDuration: TimeInterval = 0
    @State private var walking = false
    @State private var facingLeft = false

    // Building in & selection
    @State private var popStart = Date.distantPast
    @State private var popping = false
    @State private var bounceStart = Date.distantPast
    @State private var bouncing = false
    @State private var bounceTargets: Set<Int> = []

    private var interactive: Bool { onTap != nil }

    /// The character's height in island units: constant against the world.
    static let characterHeight: CGFloat = 24

    var body: some View {
        GeometryReader { geo in
            // `base` is the camera without the pan (for touches, which subtract the pan);
            // `layout` has the pan built in, for drawing.
            let base = IslandLayout(island: island, size: geo.size, insets: insets, zoom: zoom, angle: angle)
            let layout = base.panned(pan)
            let charH = Self.characterHeight * layout.u
            let charW = charH * 20 / 36
            let staticCount = popping ? min(revealFrom, island.items.count) : island.items.count
            let ordered = island.items.prefix(staticCount).sorted { layout.depth($0.gx, $0.gy) < layout.depth($1.gx, $1.gy) }

            ZStack(alignment: .topLeading) {
                Earthy.sea
                ZStack(alignment: .topLeading) {
                    TimelineView(.animation(minimumInterval: 1.0 / 12, paused: reduceMotion)) { context in
                        Canvas { c, _ in
                            IslandPainter.drawWaves(&c, island: island, layout: layout,
                                                    time: reduceMotion ? 0 : context.date.timeIntervalSinceReferenceDate)
                        }
                    }
                    // Settled things are drawn once; only the character, new things and the
                    // selected item redraw while animating.
                    Canvas { context, _ in
                        IslandPainter.drawTiles(&context, island: island, layout: layout)
                        if let selected = selected.wrappedValue, island.items.indices.contains(selected) {
                            Self.drawHighlight(&context, island.items[selected], layout: layout)
                        }
                        if let editing { Self.drawEditGrid(&context, island: island, layout: layout, editing: editing) }
                        // Only what's on screen (plus a margin for tall things) is drawn.
                        let visible = CGRect(origin: .zero, size: geo.size).insetBy(dx: -layout.scale * 2, dy: -layout.scale * 2)
                        for item in ordered where visible.contains(layout.point(item.gx, item.gy)) {
                            IslandPainter.drawItem(&context, item, layout: layout)
                        }
                        #if DEBUG
                        if Self.showHitBoxes { Self.drawHitBoxes(&context, island: island, layout: layout) }
                        #endif
                    }

                    TimelineView(.animation(paused: !walking && !popping && !bouncing && characters.isEmpty)) { context in
                        let now = context.date
                        let pos = position(at: now)
                        let feet = layout.point(pos.x, pos.y)
                        let t = now.timeIntervalSinceReferenceDate
                        let bounce = walking ? -abs(sin(t * 9)) * charH * 0.05 : 0
                        let lean = walking ? sin(t * 9) * 3 : 0
                        let popElapsed = now.timeIntervalSince(popStart)
                        let popStep = min(0.1, 2.0 / Double(max(1, island.items.count - staticCount)))

                        ZStack(alignment: .topLeading) {
                            // New things building in, and the selected item's bounce.
                            Canvas { c, _ in
                                if popping {
                                    for (rank, item) in island.items.enumerated().dropFirst(staticCount) {
                                        let progress = (popElapsed - Double(rank - staticCount) * popStep) / 0.45
                                        guard progress > 0 else { continue }
                                        IslandPainter.drawItem(&c, item, layout: layout, scale: progress < 1 ? Self.overshoot(progress) : 1)
                                    }
                                }
                                if bouncing {
                                    let e = now.timeIntervalSince(bounceStart)
                                    let s = 1 + 0.16 * sin(min(1, e / 0.5) * .pi) * (1 - min(1, e / 0.5))
                                    for index in bounceTargets.sorted() where island.items.indices.contains(index) {
                                        IslandPainter.drawItem(&c, island.items[index], layout: layout, scale: s)
                                    }
                                }
                            }
                            ForEach(characters) { c in
                                let time = characterTime(c.id, now: now)
                                let p = layout.point(c.position(at: time).x, c.position(at: time).y)
                                CharacterFigure(id: c.id, look: c.look)
                                    .frame(width: charH * 0.75, height: charH * 1.05)
                                    .scaleEffect(x: c.facingLeft(at: time) != layout.mirrored ? -1 : 1, y: 1)
                                    .position(x: p.x, y: p.y - charH * 0.47)
                                    .allowsHitTesting(false)
                            }
                            AvatarFigure(avatar: avatar)
                                .frame(width: charW, height: charH)
                                .scaleEffect(x: facingLeft != layout.mirrored ? -1 : 1, y: 1)
                                .rotationEffect(.degrees(lean), anchor: .bottom)
                                .offset(y: bounce)
                                .position(x: feet.x, y: feet.y - charH * 0.43)
                            // Tall things in front of a walking figure (you or a Bible character)
                            // are drawn over it, unless they're behind another figure there.
                            Canvas { c, _ in
                                let figures = [feet] + characters.map { ch -> CGPoint in
                                    let g = ch.position(at: characterTime(ch.id, now: now))
                                    return layout.point(g.x, g.y)
                                }
                                for item in ordered where item.kind.isTall {
                                    let p = layout.point(item.gx, item.gy)
                                    let near = figures.filter { abs(p.x - $0.x) < layout.scale * 1.7 && abs(p.y - $0.y) < layout.scale * 1.4 }
                                    guard near.contains(where: { p.y > $0.y }), !near.contains(where: { p.y <= $0.y }) else { continue }
                                    IslandPainter.drawItem(&c, item, layout: layout)
                                }
                            }
                            if let speaking, let c = characters.first(where: { $0.id == speaking.id }),
                               now.timeIntervalSince(speaking.since) < 7 {
                                let p = c.position(at: speaking.since.timeIntervalSinceReferenceDate)
                                let head = layout.point(p.x, p.y)
                                SpeechBubble(name: c.name, line: c.line, content: CharacterUnlocks.character(id: c.id)) {
                                    self.speaking = nil
                                    onReadStory?(c.story)
                                }
                                .fixedSize()
                                .position(x: head.x, y: head.y - charH * 1.05 - 62)
                            }
                        }
                    }
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .contentShape(Rectangle())
            .gesture(interactive ? dragGesture(layout: base, size: geo.size) : nil)
            .simultaneousGesture(interactive ? zoomGesture(size: geo.size) : nil)
            .simultaneousGesture(interactive ? twistGesture : nil)
            .overlay(alignment: .bottomTrailing) {
                if interactive && persistsCamera && editing == nil {
                    controls(layout: base, size: geo.size)
                        .padding(.trailing, 14)
                        .padding(.bottom, insets.bottom + 6)
                }
            }
            .onChange(of: visit) { _, index in
                if let index, island.items.indices.contains(index) {
                    startVisit(island.items[index], index: index, size: geo.size)
                } else if let before = cameraBeforeVisit {
                    animateCamera(zoom: before.zoom, pan: before.pan, duration: 0.5)
                    cameraBeforeVisit = nil
                }
            }
            .onChange(of: selected.wrappedValue) { _, index in
                guard let index, island.items.indices.contains(index) else { return }
                centre(on: island.items[index], layout: base, size: geo.size)
                if !reduceMotion { startBounce([index]) }
            }
        }
        .onAppear {
            loadCamera()
            placeCharacter()
        }
        .onChange(of: island.tiles.count) { _, _ in if !walking { placeCharacter() } }
        .task(id: reduceMotion) {
            guard !reduceMotion else { return }
            await wander()
        }
        .onChange(of: revealID) { _, _ in startPop() }
        .onChange(of: growID) { _, _ in if !reduceMotion { startBounce(grown, duration: 0.9) } }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Your island")
        .accessibilityValue(island.items.isEmpty ? "Bare ground" :
            "\(island.items.count) \(island.items.count == 1 ? "thing" : "things") on it")
    }

    // MARK: Controls

    private func controls(layout: IslandLayout, size: CGSize) -> some View {
        VStack(spacing: 8) {
            controlButton("arrow.counterclockwise", label: "Turn island left") { turn(by: -1) }
            controlButton("arrow.clockwise", label: "Turn island right") { turn(by: 1) }
            controlButton("scope", label: "Find me") { findMe(layout: layout, size: size) }
        }
    }

    private func controlButton(_ symbol: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Color.primaryBrown)
                .frame(width: 44, height: 44)
                .background(Color.cream.opacity(0.94), in: Circle())
                .shadow(color: Color.primaryBrown.opacity(0.12), radius: 6, y: 2)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    /// Turns the island a quarter turn, animating smoothly (instantly with Reduce Motion).
    private func turn(by step: Int) {
        let from = angle
        quarter += step
        let to = CGFloat(quarter)
        saveCamera()
        guard !reduceMotion else { angle = to; return }
        Task {
            let start = Date.now, duration = 0.4
            while true {
                let t = min(1, Date.now.timeIntervalSince(start) / duration)
                let e = t * t * (3 - 2 * t)
                angle = from + (to - from) * e
                if t >= 1 { break }
                try? await Task.sleep(for: .milliseconds(16))
            }
        }
    }

    /// Recentres on your character, zooming in if far out.
    private func findMe(layout: IslandLayout, size: CGSize) {
        let newZoom = max(zoom, 2.6)
        let target = IslandLayout(island: island, size: size, insets: insets, zoom: newZoom, angle: CGFloat(quarter))
        let feet = target.point(spot.x, spot.y)
        let centre = CGPoint(x: insets.leading + (size.width - insets.leading - insets.trailing) / 2,
                             y: insets.top + (size.height - insets.top - insets.bottom) / 2)
        animateCamera(zoom: newZoom, pan: CGSize(width: centre.x - feet.x, height: centre.y - feet.y), duration: 0.5)
        saveCamera()
    }

    /// Glides the camera to a new zoom and pan. Done frame by frame, because the island's
    /// drawing has the camera built in (SwiftUI can't interpolate a Canvas on its own).
    /// A new touch or camera move cancels a glide in progress.
    private func animateCamera(zoom toZoom: CGFloat, pan toPan: CGSize, duration: Double) {
        cameraGlide += 1
        let token = cameraGlide
        let fromZoom = zoom, fromPan = pan
        zoomStart = toZoom
        panStart = toPan
        guard !reduceMotion, duration > 0.05 else { zoom = toZoom; pan = toPan; return }
        Task {
            let start = Date.now
            while cameraGlide == token {
                let t = min(1, Date.now.timeIntervalSince(start) / duration)
                let e = t * t * (3 - 2 * t)
                zoom = fromZoom + (toZoom - fromZoom) * e
                pan = CGSize(width: fromPan.width + (toPan.width - fromPan.width) * e,
                             height: fromPan.height + (toPan.height - fromPan.height) * e)
                if t >= 1 { break }
                try? await Task.sleep(for: .milliseconds(16))
            }
        }
    }

    // MARK: Camera persistence

    private enum Keys {
        static let zoom = "island.camera.zoom", panX = "island.camera.panX", panY = "island.camera.panY"
        static let quarter = "island.camera.quarter"
    }

    private func loadCamera() {
        guard !cameraLoaded else { return }
        cameraLoaded = true
        if persistsCamera {
            let d = UserDefaults.standard
            if d.object(forKey: Keys.zoom) != nil {
                zoom = min(IslandLayout.maxZoom, max(IslandLayout.minZoom, d.double(forKey: Keys.zoom)))
                pan = CGSize(width: d.double(forKey: Keys.panX), height: d.double(forKey: Keys.panY))
                quarter = d.integer(forKey: Keys.quarter)
                angle = CGFloat(quarter)
            } else if island.plots.count >= 3 {
                // First look at a big island: start a little closer, so buildings read clearly.
                zoom = min(2, 1 + CGFloat(island.plots.count) * 0.12)
            }
        }
        #if DEBUG
        // "-islandZoom 3" starts zoomed in, "-islandTurn 1" turned (for checking art).
        let args = ProcessInfo.processInfo.arguments
        if let i = args.firstIndex(of: "-islandZoom"), i + 1 < args.count, let z = Double(args[i + 1]) {
            zoom = min(IslandLayout.maxZoom, max(IslandLayout.minZoom, z)); pan = .zero
        }
        if let i = args.firstIndex(of: "-islandTurn"), i + 1 < args.count, let q = Int(args[i + 1]) {
            quarter = q; angle = CGFloat(q)
        }
        // "-islandPan 300,-200" starts panned (for checking the edges when zoomed in).
        if let i = args.firstIndex(of: "-islandPan"), i + 1 < args.count {
            let v = args[i + 1].split(separator: ",").compactMap { Double($0) }
            if v.count == 2 { pan = CGSize(width: v[0], height: v[1]) }
        }
        #endif
        zoomStart = zoom
        panStart = pan
    }

    private func saveCamera() {
        guard persistsCamera else { return }
        let d = UserDefaults.standard
        d.set(Double(zoomStart), forKey: Keys.zoom)
        d.set(Double(panStart.width), forKey: Keys.panX)
        d.set(Double(panStart.height), forKey: Keys.panY)
        d.set(quarter, forKey: Keys.quarter)
    }

    // MARK: Gestures

    /// One drag gesture tells taps from pans: under 10pt of movement is a tap.
    private func dragGesture(layout: IslandLayout, size: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                if !touchDown { touchBegan(at: value.startLocation, layout: layout) }
                // In edit mode, dragging a plot moves it (in whole tiles) instead of panning.
                if let drag = draggingPlot, let editing {
                    let g = layout.grid(CGPoint(x: value.location.x - pan.width, y: value.location.y - pan.height))
                    editing.onDrag(drag.key, Int((g.x - drag.start.x).rounded()), Int((g.y - drag.start.y).rounded()), false)
                    return
                }
                if !isPanning, !TapClassifier.isTap(translation: value.translation) { isPanning = true }
                if isPanning {
                    pan = clamp(CGSize(width: panStart.width + value.translation.width,
                                       height: panStart.height + value.translation.height), size: size)
                }
            }
            .onEnded { value in
                defer { pinched = false; touchDown = false; longPressed = false; draggingPlot = nil }
                if let drag = draggingPlot, let editing {
                    let g = layout.grid(CGPoint(x: value.location.x - pan.width, y: value.location.y - pan.height))
                    let moved = !TapClassifier.isTap(translation: value.translation)
                    editing.onDrag(drag.key, Int((g.x - drag.start.x).rounded()), Int((g.y - drag.start.y).rounded()), true)
                    if !moved { editing.onSelect(drag.key) }
                    return
                }
                if isPanning {
                    isPanning = false
                    panStart = pan
                    saveCamera()
                } else if !pinched, !longPressed, TapClassifier.isTap(translation: value.translation) {
                    if let editing {
                        editing.onSelect(nil)
                    } else if let c = character(at: value.location, layout: layout) {
                        speaking = (c.id, .now)
                    } else {
                        speaking = nil
                        onTap?(IslandHitTester.hit(point: value.location, layout: layout, pan: pan, items: island.items))
                    }
                }
            }
    }

    /// The time a character's walk is drawn at: frozen while they talk.
    private func characterTime(_ id: String, now: Date) -> TimeInterval {
        if let speaking, speaking.id == id, now.timeIntervalSince(speaking.since) < 7 {
            return speaking.since.timeIntervalSinceReferenceDate
        }
        return now.timeIntervalSinceReferenceDate
    }

    /// The character under a tap, if any (44pt minimum target).
    private func character(at location: CGPoint, layout: IslandLayout) -> IslandCharacter? {
        let charH = Self.characterHeight * layout.u
        let p = CGPoint(x: location.x - pan.width, y: location.y - pan.height)
        let candidates = characters.map { c -> HitCandidate<String> in
            let g = c.position(at: characterTime(c.id, now: .now))
            let feet = layout.point(g.x, g.y)
            return HitCandidate(id: c.id, depth: feet.y, onGround: false,
                                bounds: CGRect(x: feet.x - charH * 0.37, y: feet.y - charH * 1.05, width: charH * 0.75, height: charH * 1.05))
        }
        return HitPicker.pick(p, from: candidates, minimumTarget: IslandHitTester.minimumTarget).flatMap { id in characters.first { $0.id == id } }
    }

    /// A finger went down: in edit mode, grab the plot under it; otherwise watch for a long press.
    private func touchBegan(at location: CGPoint, layout: IslandLayout) {
        touchDown = true
        if zoom != zoomStart || pan != panStart { zoomStart = zoom; panStart = pan }
        cameraGlide += 1
        touchID += 1
        let id = touchID
        let p = CGPoint(x: location.x - pan.width, y: location.y - pan.height)
        let g = layout.grid(p)
        if editing != nil {
            // The plot under the finger, or the one whose building was touched.
            let hitKey = IslandHitTester.hit(point: location, layout: layout, pan: pan, items: island.items)
                .flatMap { island.items[$0].plotKey }
            let plots = island.plots + (island.library.map { [$0] } ?? [])
            if let key = hitKey ?? plots.first(where: { CGRect(x: $0.x, y: $0.y, width: $0.size, height: $0.size).contains(g) })?.bookID {
                draggingPlot = (key, g)
            }
            return
        }
        guard let onLongPress else { return }
        Task {
            try? await Task.sleep(for: .milliseconds(500))
            guard touchDown, touchID == id, !isPanning, !pinched,
                  let index = IslandHitTester.hit(point: location, layout: layout, pan: pan, items: island.items),
                  island.items[index].plotKey != nil else { return }
            longPressed = true
            onLongPress(index)
        }
    }

    private func zoomGesture(size: CGSize) -> some Gesture {
        MagnifyGesture()
            .onChanged { value in
                pinched = true
                let z = min(IslandLayout.maxZoom, max(IslandLayout.minZoom, zoomStart * value.magnification))
                let ratio = z / zoom
                zoom = z
                pan = clamp(CGSize(width: pan.width * ratio, height: pan.height * ratio), size: size)
            }
            .onEnded { _ in
                zoomStart = zoom
                panStart = pan
                saveCamera()
            }
    }

    /// A two-finger twist of more than 30° turns the island a quarter turn that way.
    private var twistGesture: some Gesture {
        RotateGesture(minimumAngleDelta: .degrees(8))
            .onChanged { _ in pinched = true }
            .onEnded { value in
                let degrees = value.rotation.degrees
                if degrees > 30 { turn(by: 1) } else if degrees < -30 { turn(by: -1) }
            }
    }

    /// Keeps the island on screen however far you zoom.
    private func clamp(_ p: CGSize, size: CGSize) -> CGSize {
        let maxX = (zoom - 1) * size.width / 2 + size.width * 0.25
        let maxY = (zoom - 1) * size.height / 2 + size.height * 0.25
        return CGSize(width: min(maxX, max(-maxX, p.width)), height: min(maxY, max(-maxY, p.height)))
    }

    /// Eases the view so the selected item sits in the middle of the free area.
    private func centre(on item: Island.Item, layout: IslandLayout, size: CGSize) {
        let base = layout.point(item.gx, item.gy)
        let target = CGPoint(x: insets.leading + (size.width - insets.leading - insets.trailing) / 2,
                             y: insets.top + (size.height - insets.top - insets.bottom) * 0.35)
        let desired = clamp(CGSize(width: target.x - base.x, height: target.y - base.y), size: size)
        // Ease only part of the way, so it feels like a nudge rather than a jump.
        let eased = CGSize(width: pan.width + (desired.width - pan.width) * 0.6,
                           height: pan.height + (desired.height - pan.height) * 0.6)
        animateCamera(zoom: zoom, pan: eased, duration: 0.45)
    }

    private func startBounce(_ targets: Set<Int>, duration: Double = 0.55) {
        bounceTargets = targets
        bounceStart = .now
        bouncing = true
        Task {
            try? await Task.sleep(for: .seconds(duration))
            bouncing = false
        }
    }

    /// Edit mode: a faint tile grid, and each plot outlined (green when picked and free,
    /// red where it would overlap another).
    private static func drawEditGrid(_ c: inout GraphicsContext, island: Island, layout: IslandLayout, editing: IslandEditing) {
        let grid = Path { p in
            for t in island.tiles {
                p.addLines([layout.point(CGFloat(t.x), CGFloat(t.y)), layout.point(CGFloat(t.x + 1), CGFloat(t.y)),
                            layout.point(CGFloat(t.x + 1), CGFloat(t.y + 1)), layout.point(CGFloat(t.x), CGFloat(t.y + 1))])
                p.closeSubpath()
            }
        }
        c.stroke(grid, with: .color(Color.primaryBrown.opacity(0.12)), lineWidth: 0.6)
        for plot in island.plots + (island.library.map { [$0] } ?? []) {
            let x0 = CGFloat(plot.x), y0 = CGFloat(plot.y), x1 = x0 + CGFloat(plot.size), y1 = y0 + CGFloat(plot.size)
            let outline = Path { $0.addLines([layout.point(x0, y0), layout.point(x1, y0), layout.point(x1, y1), layout.point(x0, y1)]); $0.closeSubpath() }
            if island.conflicts.contains(plot.bookID) {
                c.fill(outline, with: .color(Color.red.opacity(0.22)))
                c.stroke(outline, with: .color(Color.red.opacity(0.8)), lineWidth: 2)
            } else if editing.selected == plot.bookID {
                c.fill(outline, with: .color(Color.green.opacity(0.16)))
                c.stroke(outline, with: .color(Color(hex: "#5E8C4A")), lineWidth: 2)
            } else {
                c.stroke(outline, with: .color(Color.primaryBrown.opacity(0.35)), style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
            }
        }
    }

    private static func drawHighlight(_ c: inout GraphicsContext, _ item: Island.Item, layout: IslandLayout) {
        let base = layout.point(item.gx, item.gy)
        let w = max(item.footprint.width, 0.5) * layout.scale * 2.2
        c.fill(Path(ellipseIn: CGRect(x: base.x - w / 2, y: base.y - w * 0.22, width: w, height: w * 0.44)),
               with: .color(Color.wheat.opacity(0.55)))
    }

    #if DEBUG
    /// `-showHitBoxes`: outlines each item's tap area (drawn bounds in red, ground in blue,
    /// 44pt minimum in grey) to diagnose taps that miss.
    private static let showHitBoxes = ProcessInfo.processInfo.arguments.contains("-showHitBoxes")

    private static func drawHitBoxes(_ c: inout GraphicsContext, island: Island, layout: IslandLayout) {
        for item in island.items {
            let bounds = IslandPainter.drawnBounds(of: item, layout: layout)
            c.stroke(Path(HitPicker.expanded(bounds, to: IslandHitTester.minimumTarget)), with: .color(.gray.opacity(0.5)), lineWidth: 1)
            c.stroke(Path(bounds), with: .color(.red), lineWidth: 1)
            let f = item.footprint
            var ground = Path()
            ground.move(to: layout.point(f.minX, f.minY))
            ground.addLine(to: layout.point(f.maxX, f.minY))
            ground.addLine(to: layout.point(f.maxX, f.maxY))
            ground.addLine(to: layout.point(f.minX, f.maxY))
            ground.closeSubpath()
            c.stroke(ground, with: .color(.blue), lineWidth: 1)
        }
    }
    #endif

    private static func overshoot(_ t: Double) -> CGFloat {
        let c1 = 1.7, c3 = c1 + 1
        return CGFloat(1 + c3 * pow(t - 1, 3) + c1 * pow(t - 1, 2))
    }

    // MARK: Walking

    /// Start somewhere sensible: the starting square.
    private func placeCharacter() {
        guard let tile = island.tiles.first, !island.tiles.contains(where: { hypot(Double($0.x) + 0.5 - spot.x, Double($0.y) + 0.5 - spot.y) < 0.6 }) else { return }
        spot = CGPoint(x: Double(tile.x) + 0.5, y: Double(tile.y) + 0.5)
        walkFrom = spot
    }

    private func position(at date: Date) -> CGPoint {
        guard walking, walkDuration > 0 else { return spot }
        let t = min(1, max(0, date.timeIntervalSince(walkStart) / walkDuration))
        let e = t * t * (3 - 2 * t)
        return CGPoint(x: walkFrom.x + (spot.x - walkFrom.x) * e, y: walkFrom.y + (spot.y - walkFrom.y) * e)
    }

    /// Stroll to a nearby spot on the island, pause, repeat.
    private func wander() async {
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(Double.random(in: 1.2...3.5)))
            guard !Task.isCancelled else { return }
            let nearby = island.tiles.filter { hypot(Double($0.x) + 0.5 - spot.x, Double($0.y) + 0.5 - spot.y) < 2.6 }
            guard let tile = nearby.randomElement() else { continue }
            let target = CGPoint(x: Double(tile.x) + Double.random(in: 0.2...0.8), y: Double(tile.y) + Double.random(in: 0.2...0.8))
            guard visit == nil else { continue } // stay at the door while visiting
            await walk(to: target)
        }
    }

    /// Walks the character to a grid point at a stroll.
    private func walk(to target: CGPoint, speed: Double = 0.55, maxDuration: Double = 30) async {
        let distance = hypot(target.x - spot.x, target.y - spot.y)
        guard distance > 0.3 else { return }
        walkToken += 1
        let token = walkToken
        facingLeft = (target.x - target.y) < (spot.x - spot.y)
        walkFrom = position(at: .now)
        walkDuration = min(maxDuration, max(0.8, distance / speed))
        walkStart = .now
        spot = target
        walking = true
        try? await Task.sleep(for: .seconds(walkDuration))
        if walkToken == token { walking = false }
    }

    /// Walks to a building's door (just in front of it) while easing the camera in.
    private func startVisit(_ item: Island.Item, index: Int, size: CGSize) {
        speaking = nil
        if cameraBeforeVisit == nil { cameraBeforeVisit = (zoom, pan) }
        let door = CGPoint(x: item.gx + 0.62, y: item.gy + 0.62)
        let newZoom = max(zoom, 3)
        let target = IslandLayout(island: island, size: size, insets: insets, zoom: newZoom, angle: CGFloat(quarter))
        let p = target.point(door.x, door.y)
        let centre = CGPoint(x: insets.leading + (size.width - insets.leading - insets.trailing) / 2,
                             y: insets.top + (size.height - insets.top - insets.bottom) * 0.55)
        let walkTime = min(2.2, max(0.6, hypot(door.x - spot.x, door.y - spot.y) / 2.2))
        animateCamera(zoom: newZoom, pan: CGSize(width: centre.x - p.x, height: centre.y - p.y), duration: walkTime)
        Task {
            if reduceMotion {
                spot = door; walkFrom = door
            } else {
                await walk(to: door, speed: 2.2, maxDuration: walkTime)
                try? await Task.sleep(for: .milliseconds(150))
            }
            onArrived?(index)
        }
    }

    private func startPop() {
        let count = island.items.count - revealFrom
        guard count > 0, !reduceMotion else { return }
        popStart = .now
        popping = true
        let duration = min(0.1, 2.0 / Double(count)) * Double(count) + 0.6
        Task {
            try? await Task.sleep(for: .seconds(duration))
            popping = false
        }
    }
}
