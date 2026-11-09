import SwiftUI

/// The island, filling the screen and set in the sea: pinch to zoom, drag to pan, twist (or
/// use the turn buttons) to rotate it a quarter turn, tap an object to inspect it. Your
/// character strolls around on it at a constant size, so it looks smaller as the island grows.
struct PlatformScene: View {
    let avatar: Avatar
    let island: Island
    /// The "see it built" moment: these beats play when `revealID` changes, starting from
    /// `revealInitial` (the growth each changing item showed before).
    var reveal: [RevealStep] = []
    var revealInitial: [Int: CGFloat] = [:]
    var revealID = 0
    /// Told which beat is playing (nil when none), for the caption.
    var onRevealStep: ((RevealStep?) -> Void)? = nil
    /// Room kept clear of the island (for the status pill and the bottom bar).
    var insets = EdgeInsets()
    var selected: Binding<Int?> = .constant(nil)
    /// Your own island keeps its camera (zoom, pan, turn) between launches and shows the
    /// turn and "Find me" buttons. Friends' islands don't.
    var persistsCamera = false
    /// Shows the turn and "Find me" buttons (your island, and friends' islands).
    var showsControls: Bool? = nil
    /// Edit mode: plots can be dragged and turned (see `IslandEditing`). Nil = not editing.
    var editing: IslandEditing? = nil
    /// Holding a building for half a second (outside edit mode) reports its index.
    var onLongPress: ((Int) -> Void)? = nil
    /// Unlocked Bible characters strolling around their books' plots.
    var characters: [IslandCharacter] = []
    /// "Read their story" in a character's speech bubble.
    var onViewJourney: ((String) -> Void)? = nil
    /// Visiting a building: your character walks to its door while the camera eases in,
    /// then `onArrived` is called. Setting it back to nil restores the camera.
    var visit: Int? = nil
    var onArrived: ((Int) -> Void)? = nil
    /// Villagers, travellers, smoke and baskets (paused while editing; only what's on screen moves).
    var life = IslandLife()
    /// Tapping a basket of produce above a Place (its book id).
    var onBasket: ((String) -> Void)? = nil
    /// Tapping the crowd in the plaza.
    var onCrowd: (() -> Void)? = nil
    /// Collect All: the produce flying from on-screen baskets into the button, whose frame (in
    /// global coordinates) is `collectTarget`. `onCollectLanded` is called when it has all landed.
    var collectFlight: CollectFlight? = nil
    var collectTarget: CGRect = .zero
    var onCollectLanded: (() -> Void)? = nil
    /// DEBUG: a frames-per-second readout.
    var showsFPS = false
    /// Covered by a full-screen view (an interior, or a sheet pulled to full height): all animation
    /// holds still until it closes.
    var paused = false
    /// Partly covered (a half-height sheet): villagers and characters move at a lower frame rate,
    /// leaving the main thread to the sheet.
    var throttled = false
    /// Called with the tapped item's index (nil for empty ground). Nil callback = read-only.
    var onTap: ((Int?) -> Void)? = nil

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase

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
    /// A tap-to-zoom move is playing: touches are ignored until it lands.
    @State private var cameraLocked = false
    /// A camera glide is playing (for `cameraMoving`).
    @State private var gliding = false
    /// The whole-island overview and the pictures around the first view have been made.
    @State private var preloaded = false
    /// The view's size (for camera moves started outside the geometry reader).
    @State private var viewSize: CGSize = .zero
    /// The last tap on empty ground, for double-tap to zoom.
    @State private var lastGroundTap: (time: Date, at: CGPoint)?
    /// While revealing: the growth each changing item shows (0 = hidden), and the beat playing.
    @State private var overrides: [Int: CGFloat] = [:]
    @State private var beat: (step: RevealStep, start: Date)?
    @State private var revealToken = 0
    /// Level of detail and each figure's own clock (see IslandLOD.swift).
    @State private var director = LifeDirector()
    /// Items in drawing order, sorted only when something changes (see IslandLayers.swift).
    @State private var depthOrder = IslandDepthOrder()
    /// Quarter turns: the one animating (a picture of the old quarter) and at most one waiting.
    @State private var turnQueue = TurnQueue()
    @State private var turnSnapshot: TurnSnapshot?
    @State private var turnFaded = false
    // Pinch: the point it started at, and the camera then.
    @State private var pinchAnchor: CGPoint?
    @State private var pinchFrom: (zoom: CGFloat, pan: CGSize)?
    // Collect All in flight.
    @State private var flight: (sprites: [CollectFlightPlan.Sprite], start: Date)?
    /// The view's frame in global coordinates (to aim the flight at the button).
    @State private var globalOrigin: CGPoint = .zero

    // Character
    @State private var spot = CGPoint(x: 1, y: 1)
    @State private var walkFrom = CGPoint(x: 1, y: 1)
    @State private var walkStart = Date.distantPast
    @State private var walkDuration: TimeInterval = 0
    @State private var walking = false
    @State private var facingLeft = false

    // Selection
    @State private var bounceStart = Date.distantPast
    @State private var bouncing = false
    @State private var bounceTargets: Set<Int> = []

    private var interactive: Bool { onTap != nil }

    /// The character's height in island units: constant against the world.
    static let characterHeight: CGFloat = 24
    /// How far beyond the screen villagers, travellers and characters are looked after (points).
    static let lifeMargin: CGFloat = 140

    var body: some View {
        GeometryReader { geo in
            // `base` is the camera without the pan (for touches, which subtract the pan);
            // `layout` has the pan built in, for drawing.
            let base = IslandLayout(island: island, size: geo.size, insets: insets, zoom: zoom, angle: angle)
            let layout = base.panned(pan)
            let charH = Self.characterHeight * layout.u
            let charW = charH * 0.625 // the avatar canvas is 100 × 160
            let moving = Set(beat?.step.changes.map(\.index) ?? [])
            // Back-to-front order, worked out only when something is added, moves or turns.
            let _ = depthOrder.update(island: island, layout: layout, overrides: overrides, hidden: moving)
            let ordered = depthOrder.all
            let _ = { RenderStats.nodes = island.items.count + life.villagers.count + life.travellers.count + characters.count }()
            // The still layers are always worked out from the camera now (position and zoom), so
            // whatever comes into view, zooming out too, is there at once.
            let drawPan = PanStep.drawPan(pan)
            let slide = PanStep.offset(pan)
            // Mid-zoom (a pinch, or a glide to a new zoom), detail level stays at the settled zoom.
            let zooming = pinchAnchor != nil || zoom != zoomStart
            let settledU = layout.u * zoomStart / max(0.001, zoom)

            ZStack(alignment: .topLeading) {
                Earthy.sea
                ZStack(alignment: .topLeading) {
                    // The waves and the still island are drawn at a rounded pan and slid into place,
                    // so panning only moves them (see IslandLayers.swift).
                    // The sea follows the camera itself, even mid-zoom, so it always fills the screen.
                    IslandWavesLayer(key: .init(signature: island.signature, zoom: zoom, angle: angle, pan: PanStep.drawPan(pan), size: geo.size,
                                                insets: insets, reduceMotion: reduceMotion,
                                                // Far out the surf is too small to see move: it holds still.
                                                paused: paused || director.isIdleFarOut),
                                     island: island)
                        .equatable()
                        // Bigger than the screen: overflow down and right, never resizing the stack.
                        .frame(width: geo.size.width, height: geo.size.height, alignment: .topLeading)
                        .offset(PanStep.offset(pan))
                    // Far out (everyone faded away) nothing moving is big enough to see: no frames are
                    // spent on the people layer until something happens or you zoom back in.
                    TimelineView(.animation(minimumInterval: throttled ? 1.0 / 30 : nil, paused: paused || (!walking && beat == nil && !bouncing && flight == nil
                                            && (characters.isEmpty || director.isIdleFarOut)
                                            && (life.isEmpty || editing != nil || reduceMotion || director.isIdleFarOut)))) { context in
                        let now = context.date
                        let pos = position(at: now)
                        let feet = layout.point(pos.x, pos.y)
                        let t = now.timeIntervalSinceReferenceDate
                        let bounce = walking ? -abs(sin(t * 9)) * charH * 0.05 : 0
                        let lean = walking ? sin(t * 9) * 3 : 0
                        let screen = CGRect(origin: .zero, size: geo.size)
                        // One visible rect with a generous margin, for people and buildings alike:
                        // things are picked up (and people faded in) well before they come into view,
                        // and only added or dropped as they cross it.
                        let viewport = screen.insetBy(dx: -Self.lifeMargin, dy: -Self.lifeMargin)
                        let lifeTime = reduceMotion ? 0 : t
                        // Level of detail changes only once a zoom settles, never on every step of a pinch.
                        let tier = director.begin(now: lifeTime, u: zooming ? settledU : layout.u)
                        let shown: [LifeDirector.Shown] = editing == nil ? PerfProbe.measure("tick.plan") {
                            let figures: () -> [LifeDirector.Figure] = {
                                life.figures(layout: layout, viewport: viewport) + characterFigures(layout: layout, charH: charH)
                            }
                            return director.plan(figures(), now: lifeTime, viewport: viewport, screen: screen)
                        } : []
                        let shownCharacters: [String: LifeDirector.Shown] = Self.characterMap(shown)
                        let lifeOn = editing == nil && !life.isEmpty
                        let lifeShown = lifeOn ? shown.filter { !$0.id.hasPrefix("c:") } : []
                        let shownCast = characters.filter { shownCharacters[$0.id] != nil }

                        // People over the still island. Anyone standing behind a building gets the
                        // island in front of them drawn again, clipped to just their own rect, in the
                        // island's own back-to-front order: buildings are never copied anywhere else.
                        let people = Self.people(feet: feet, charW: charW, charH: charH, cast: shownCast.map(\.id),
                                                 shownCharacters: shownCharacters, life: lifeShown, u: layout.u)
                        let near = people.reduce(CGRect.null) { $0.union($1.rect) }.intersection(viewport)
                        let nearItems = near.isNull ? [] : PerfProbe.measure("tick.items") {
                            IslandWorld.visibleItems(ordered, layout: layout, visible: near)
                        }
                        let over: [[Int]] = PerfProbe.measure("tick.order") {
                            people.map { IslandWorld.itemsOver($0, items: nearItems, layout: layout) }
                        }
                        let lifeByID = Dictionary(lifeShown.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
                        let basketsOn = editing == nil && !life.baskets.isEmpty && layout.u >= IslandLife.minimumBasketU
                        let _ = { RenderStats.figures = people.count; RenderStats.life = over.reduce(0) { $0 + $1.count } }()

                        let canvasSize = PanStep.canvasSize(geo.size)
                        ZStack(alignment: .topLeading) {
                        // The world: ground, buildings, people, effects, birds and baskets, all drawn in
                        // one place (the ground's own coordinates) from the same camera in the same
                        // update, and moved into view together by one offset. Nothing on the island is
                        // positioned in screen space on its own, so nothing can drift against the land.
                        ZStack(alignment: .topLeading) {
                            IslandGroundLayer(key: .init(signature: island.signature, zoom: zoom, angle: angle, pan: drawPan, size: geo.size,
                                                         insets: insets, selected: selected.wrappedValue, editing: editing != nil,
                                                         editSelected: editing?.selected, overrides: overrides, hidden: moving,
                                                         rendered: IslandRenderProgress.shared.generation),
                                              island: island, ordered: ordered, editing: editing)
                                .equatable()
                                .zIndex(-1)
                            if beat != nil || !overrides.isEmpty {
                                // The rest of the island dims a little while something is built.
                                Color.black.opacity(0.16).frame(width: canvasSize.width, height: canvasSize.height)
                                    .allowsHitTesting(false).transition(.opacity).zIndex(IslandLayer.dim.z)
                            }
                            Canvas { c, _ in
                                // Worked out in view points; drawn in the world's coordinates.
                                c.translateBy(x: -slide.width, y: -slide.height)
                                PerfProbe.measure("life") {
                                    if lifeOn && tier == .far {
                                        _ = IslandLife.drawFarBoats(&c, life: life, director: director, layout: layout, time: lifeTime, visible: viewport)
                                    }
                                    // Smoke rises above the roofs (under the people, as before).
                                    if lifeOn { _ = IslandLife.drawSmoke(&c, life: life, tier: tier, layout: layout, time: lifeTime, visible: viewport) }
                                    for (k, person) in people.enumerated() {
                                        if person.id == "me" {
                                            if let me = c.resolveSymbol(id: "me") {
                                                c.draw(me, at: CGPoint(x: feet.x, y: feet.y + charH * 0.07 + bounce), anchor: .bottom)
                                            }
                                        } else if person.id.hasPrefix("c:") {
                                            if let symbol = c.resolveSymbol(id: person.id), let shown = shownCharacters[String(person.id.dropFirst(2))] {
                                                var g = c
                                                g.opacity = shown.opacity
                                                g.draw(symbol, at: CGPoint(x: shown.point.x, y: shown.point.y + charH * 0.055), anchor: .bottom)
                                            }
                                        } else if let shown = lifeByID[person.id] {
                                            IslandLife.drawFigure(&c, shown, life: life, layout: layout)
                                        }
                                        // The island in front of them, over them, inside their rect only.
                                        if !over[k].isEmpty {
                                            var g = c
                                            g.clip(to: Path(person.rect.insetBy(dx: -1, dy: -1)))
                                            for i in over[k] {
                                                // Mid-zoom, drawn directly rather than rendering a new picture each step.
                                                if zooming { IslandPainter.drawItem(&g, nearItems[i].item, layout: layout) }
                                                else { IslandRenderCache.shared.drawItem(&g, nearItems[i].item, layout: layout) }
                                            }
                                        }
                                    }
                                }
                            } symbols: {
                                AvatarFigure(avatar: avatar)
                                    .frame(width: charW, height: charH)
                                    .scaleEffect(x: facingLeft != layout.mirrored ? -1 : 1, y: 1)
                                    .rotationEffect(.degrees(lean), anchor: .bottom)
                                    .tag("me" as String)
                                ForEach(shownCast) { c in
                                    CharacterFigure(id: c.characterId, look: c.look)
                                        .frame(width: charH * 0.75, height: charH * 1.05)
                                        .scaleEffect(x: c.facingLeft(at: shownCharacters[c.id]?.time ?? 0) != layout.mirrored ? -1 : 1, y: 1)
                                        .tag("c:" + c.id as String)
                                }
                            }
                            .frame(width: canvasSize.width, height: canvasSize.height)
                            .allowsHitTesting(false)
                            .zIndex(IslandLayer.people.z)

                            if beat != nil || bouncing {
                                Canvas { c, _ in
                                    c.translateBy(x: -slide.width, y: -slide.height)
                                    // The piece being built, and the selected item's bounce.
                                    if let beat {
                                        Self.drawBeat(&c, beat.step, elapsed: now.timeIntervalSince(beat.start), island: island, layout: layout)
                                    }
                                    if bouncing {
                                        let e = now.timeIntervalSince(bounceStart)
                                        let s = 1 + 0.16 * sin(min(1, e / 0.5) * .pi) * (1 - min(1, e / 0.5))
                                        for index in bounceTargets.sorted() where island.items.indices.contains(index) {
                                            IslandPainter.drawItem(&c, island.items[index], layout: layout, scale: s)
                                        }
                                    }
                                }
                                .frame(width: canvasSize.width, height: canvasSize.height)
                                .allowsHitTesting(false)
                                .zIndex(IslandLayer.effects.z)
                            }
                            if lifeOn && tier != .far {
                                // Birds: their own layer, above everything on the island (never
                                // depth-sorted); far out they're too small to see and aren't drawn.
                                Canvas { c, _ in
                                    c.translateBy(x: -slide.width, y: -slide.height)
                                    IslandLife.birds(&c, layout: layout, sky: life.sky, visible: viewport, time: lifeTime)
                                }
                                .frame(width: canvasSize.width, height: canvasSize.height)
                                .allowsHitTesting(false)
                                .zIndex(IslandLayer.birds.z)
                            }
                            if basketsOn {
                                Canvas { c, _ in
                                    c.translateBy(x: -slide.width, y: -slide.height)
                                    PerfProbe.measure("front") {
                                        // Baskets go on top of everything, so they're always easy to see and tap.
                                        IslandLife.drawBaskets(&c, life: life, layout: layout, time: reduceMotion ? 0 : t,
                                                               visible: screen.insetBy(dx: -30, dy: -30))
                                    }
                                }
                                .frame(width: canvasSize.width, height: canvasSize.height)
                                .allowsHitTesting(false)
                                .zIndex(IslandLayer.baskets.z)
                            }
                        }
                        .frame(width: geo.size.width, height: geo.size.height, alignment: .topLeading)
                        .offset(slide)
                            if flight != nil {
                                // Collect All: produce flies from the island to a button on screen.
                                Canvas { c, _ in
                                    PerfProbe.measure("front") {
                                        if let flight {
                                            let target = CGPoint(x: collectTarget.midX - globalOrigin.x, y: collectTarget.midY - globalOrigin.y)
                                            _ = CollectFlightPlan.draw(&c, sprites: flight.sprites, elapsed: now.timeIntervalSince(flight.start),
                                                                       layout: layout, target: target)
                                        }
                                    }
                                }
                                .allowsHitTesting(false)
                                .zIndex(IslandLayer.baskets.z)
                            }
                            if let speaking, let c = characters.first(where: { $0.id == speaking.id }),
                               now.timeIntervalSince(speaking.since) < 7, let time = director.peek("c:\(c.id)") {
                                let p = c.position(at: time)
                                let head = layout.point(p.x, p.y)
                                SpeechBubble(name: c.name, line: c.line, content: CharacterJourneys.journey(id: c.id)) {
                                    self.speaking = nil
                                    onViewJourney?(c.id)
                                }
                                .fixedSize()
                                .position(x: head.x, y: head.y - charH * 1.05 - 62)
                                .zIndex(IslandLayer.bubbles.z)
                            }
                        }
                    }
                }
                // Turning: the island already shows the new quarter, fading and easing in, while a
                // picture of how it looked turns away and fades out. Only layer opacity and
                // rotation animate; nothing is redrawn.
                .opacity(turnSnapshot == nil || turnFaded ? 1 : 0)
                .rotationEffect(.degrees(turnSnapshot.map { turnFaded ? 0 : -Double($0.direction) * Self.turnTilt } ?? 0))
                if let turnSnapshot {
                    TurnSnapshotView(snapshot: turnSnapshot)
                        .equatable()
                        .opacity(turnFaded ? 0 : 1)
                        .rotationEffect(.degrees(turnFaded ? Double(turnSnapshot.direction) * Self.turnTilt : 0))
                        .allowsHitTesting(false)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .contentShape(Rectangle())
            .onAppear {
                viewSize = geo.size
                globalOrigin = geo.frame(in: .global).origin
                // A saved zoom from a bigger island can't go past this one's limit.
                let limit = maxZoom(geo.size)
                if zoom > limit { zoom = limit; zoomStart = limit; pan = clamp(pan, size: geo.size); panStart = pan }
            }
            .onChange(of: geo.size) { _, size in viewSize = size; globalOrigin = geo.frame(in: .global).origin }
            .onChange(of: geo.frame(in: .global).origin) { _, origin in globalOrigin = origin }
            .onChange(of: collectFlight?.id) { _, _ in
                if let collectFlight { startFlight(collectFlight, layout: layout, size: geo.size) }
            }
            .gesture(interactive ? dragGesture(layout: base, size: geo.size) : nil)
            .simultaneousGesture(interactive ? zoomGesture(size: geo.size) : nil)
            .simultaneousGesture(interactive ? twistGesture : nil)
            #if DEBUG
            .overlay(alignment: .topTrailing) {
                if showsFPS { FPSMeter().padding(.top, insets.top - 8).padding(.trailing, 12).allowsHitTesting(false) }
            }
            #endif
            .overlay(alignment: .bottomTrailing) {
                if interactive && (showsControls ?? persistsCamera) && editing == nil && beat == nil && overrides.isEmpty {
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
                // A building you step into is centred by the visit (one glide, not two racing), and
                // doesn't bounce: it would be drawn again over its neighbours mid-zoom.
                if visit != index {
                    centre(on: island.items[index], size: geo.size)
                    if !reduceMotion { startBounce([index]) }
                }
            }
        }
        .onAppear {
            loadCamera()
            placeCharacter()
            #if DEBUG
            // "-autoPan" keeps the camera circling, for measuring frame rate while panning.
            // "-autoTurn" turns the island a quarter every 1.5 s, for measuring rotation.
            // "-autoTurn 3" turns every 3 s instead.
            let args = ProcessInfo.processInfo.arguments
            if let i = args.firstIndex(of: "-autoTurn") {
                let every = i + 1 < args.count ? Double(args[i + 1]) ?? 1.5 : 1.5
                Task {
                    while true {
                        try? await Task.sleep(for: .seconds(every))
                        turn(by: 1)
                    }
                }
            }
            // "-autoZoom" pinches in and out (1.6 s each way, about a point off centre) through the
            // same code as a real pinch, once per screen refresh, for measuring zoom.
            if ProcessInfo.processInfo.arguments.contains("-autoZoom") {
                Task {
                    try? await Task.sleep(for: .seconds(2))
                    while true {
                        let size = viewSize
                        let at = CGPoint(x: size.width * 0.4, y: size.height * 0.45)
                        for (from, to) in [(1.0, 3.0), (1.0, 1 / 3.0)] {
                            let start = CACurrentMediaTime()
                            while true {
                                let t = min(1, (CACurrentMediaTime() - start) / 1.6)
                                pinchChanged(magnification: from + (to - from) * t, at: at, size: size)
                                if t >= 1 { break }
                                await FrameTicker.shared.nextFrame()
                            }
                            pinchEnded(size: size)
                            try? await Task.sleep(for: .seconds(0.6))
                        }
                    }
                }
            }
            // "-autoZoomOut" pinches from close in (start with -islandZoom) all the way out once.
            if ProcessInfo.processInfo.arguments.contains("-autoZoomOut") {
                Task {
                    try? await Task.sleep(for: .seconds(2.5))
                    let size = viewSize
                    let at = CGPoint(x: size.width * 0.5, y: size.height * 0.5)
                    let target = IslandLayout.minZoom / max(zoom, 1)
                    let start = CACurrentMediaTime()
                    while true {
                        let t = min(1, (CACurrentMediaTime() - start) / 1.2)
                        pinchChanged(magnification: 1 + (target - 1) * t, at: at, size: size)
                        if t >= 1 { break }
                        await FrameTicker.shared.nextFrame()
                    }
                    pinchEnded(size: size)
                    print("ZOOMOUT ended")
                }
            }
            if ProcessInfo.processInfo.arguments.contains("-autoPan") {
                Task {
                    // "-autoPanAfter 1.5" waits that long first (a first pan a moment after launch).
                    if let wait = OpenTiming.argument("-autoPanAfter").flatMap(Double.init) { try? await Task.sleep(for: .seconds(wait)) }
                    let start = Date.now
                    // Circles around where it started (`-islandPan` to start somewhere else).
                    let base = CGSize(width: pan.width - 160, height: pan.height)
                    // Counts as a moving camera, as a finger on the screen would.
                    gliding = true
                    while true {
                        let t = Date.now.timeIntervalSince(start)
                        pan = CGSize(width: base.width + cos(t * 0.8) * 160, height: base.height + sin(t * 0.8) * 220)
                        try? await Task.sleep(for: .milliseconds(16))
                    }
                }
            }
            #endif
        }
        .onChange(of: island.tiles.count) { _, _ in if !walking { placeCharacter() } }
        .onChange(of: scenePhase) { _, phase in if phase != .active { saveCamera() } }
        .onDisappear { saveCamera() }
        // Nothing is rendered in the background while the camera moves (see `IslandRenderCache.interacting`).
        .onChange(of: cameraMoving, initial: true) { _, moving in IslandRenderCache.shared.interacting = moving }
        // When the island first appears: the whole-island overview (the last stand-in at any zoom),
        // then the pictures around the starting view, between frames, so the first pan is smooth.
        .task(id: island.signature) { await preload() }
        // Once the camera is still, render ahead what the next quarter turn either way will show.
        .task(id: WarmKey(signature: island.signature, zoom: zoomStart, pan: panStart, quarter: quarter, size: viewSize,
                          editing: editing != nil, paused: paused)) {
            await warmNextTurns()
        }
        .task(id: reduceMotion) {
            guard !reduceMotion else { return }
            await wander()
        }
        .onChange(of: revealID) { _, _ in startReveal() }
        .overlay {
            // Tap anywhere to skip the moment.
            if beat != nil || !overrides.isEmpty {
                Color.clear.contentShape(Rectangle()).onTapGesture { skipReveal() }
                    .accessibilityLabel("Skip")
                    .accessibilityAddTraits(.isButton)
            }
        }
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

    /// How long the move up to a building takes (position and zoom together, eased in and out).
    static let visitGlide = 0.7

    /// How long a quarter turn's crossfade takes, and how far the pictures tilt as they swap.
    static let turnDuration = 0.3
    static let turnTilt = 10.0

    /// Turns the island a quarter turn. A tap while one is animating waits its turn (at most one).
    private func turn(by step: Int) {
        guard let step = turnQueue.request(step) else { return }
        startTurn(step)
    }

    /// The island switches to the new quarter at once (drawn from cached pictures, never at an
    /// in-between angle), while a picture of the old quarter turns and fades away over 0.3 s.
    private func startTurn(_ step: Int) {
        let from = ((quarter % 4) + 4) % 4
        // The old quarter is on screen, so this is all cached pictures: no drawing.
        let old = viewSize == .zero || reduceMotion ? nil : IslandRenderCache.shared.frame(
            island: island, size: viewSize, insets: insets, zoom: zoom, quarter: from, pan: pan,
            overrides: overrides, hidden: [], bake: editing == nil)
        quarter += step
        angle = CGFloat(quarter)
        guard let old else { finishTurn(); return }
        turnSnapshot = TurnSnapshot(id: (turnSnapshot?.id ?? 0) + 1, frame: old, direction: step > 0 ? 1 : -1)
        turnFaded = false
        Task {
            // Let the new quarter show once beneath the picture before the fade starts.
            await FrameTicker.shared.nextFrame()
            withAnimation(.easeInOut(duration: Self.turnDuration)) { turnFaded = true }
            try? await Task.sleep(for: .seconds(Self.turnDuration))
            turnSnapshot = nil
            finishTurn()
        }
    }

    private func finishTurn() {
        if let next = turnQueue.finished() { startTurn(next) }
    }

    /// Recentres on your character, zooming in if far out.
    private func findMe(layout: IslandLayout, size: CGSize) {
        let newZoom = max(zoom, 2.6)
        animateCamera(zoom: newZoom, pan: IslandCamera.pan(toCentre: spot, island: island, size: size, insets: insets,
                                                           zoom: newZoom, quarter: quarter), duration: 0.5)
    }

    struct WarmKey: Equatable {
        let signature: Int
        let zoom: CGFloat
        let pan: CGSize
        let quarter: Int
        let size: CGSize
        let editing: Bool
        let paused: Bool
    }

    /// Renders the pictures the neighbouring quarter turns will need, one at a time between frames,
    /// only while nothing moves. A turn then finds them cached instead of drawing them on the spot.
    private func warmNextTurns() async {
        guard viewSize != .zero, !paused, island.signature != 0 else { return }
        // Well after the camera stops, so a render never lands on the first frames of the next pan.
        try? await Task.sleep(for: .seconds(1.5))
        let q = ((quarter % 4) + 4) % 4
        for target in [(q + 1) % 4, (q + 3) % 4] {
            while !Task.isCancelled {
                // Never while a finger is down, a glide runs or a turn animates.
                guard !touchDown, turnSnapshot == nil, zoom == zoomStart, pan == panStart else { return }
                let done = PerfProbe.measure("prewarm") {
                    // Exactly what the ground layer will ask for (rounded pan, canvas a step bigger than the screen).
                    IslandRenderCache.shared.prewarm(island: island, size: viewSize, insets: insets, zoom: zoom, quarter: target,
                                                     pan: PanStep.drawPan(pan), bake: editing == nil,
                                                     viewport: CGRect(origin: .zero, size: PanStep.canvasSize(viewSize)))
                }
                if done { break }
                await FrameTicker.shared.nextFrame()
            }
        }
    }

    /// The camera is moving: a finger down, a pinch, or a glide.
    private var cameraMoving: Bool { touchDown || pinchAnchor != nil || gliding }

    /// Makes the whole-island overview, then the ground and Places around the starting view (a screen
    /// further each way), one picture per frame while the camera is still.
    private func preload() async {
        guard !preloaded, island.signature != 0 else { return }
        try? await Task.sleep(for: .seconds(0.3))
        while viewSize == .zero { try? await Task.sleep(for: .seconds(0.1)) }
        let cache = IslandRenderCache.shared
        let everything = CGRect(x: -20_000, y: -20_000, width: 40_000, height: 40_000)
        let canvas = CGRect(origin: .zero, size: PanStep.canvasSize(viewSize))
        let around = canvas.insetBy(dx: -viewSize.width, dy: -viewSize.height)
        var overviewDone = false, aroundDone = false
        while !Task.isCancelled, !(overviewDone && aroundDone) {
            if !cameraMoving {
                let done = PerfProbe.measure("preload") { () -> Bool in
                    if !overviewDone {
                        overviewDone = cache.prewarm(island: island, size: viewSize, insets: insets, zoom: IslandRenderCache.overviewZoom,
                                                     quarter: quarter, pan: .zero, bake: true, viewport: everything)
                        return false
                    }
                    return cache.prewarm(island: island, size: viewSize, insets: insets, zoom: zoom, quarter: quarter,
                                         pan: PanStep.drawPan(pan), bake: editing == nil, viewport: around)
                }
                if overviewDone && done { aroundDone = true }
            }
            await FrameTicker.shared.nextFrame()
        }
        preloaded = true
    }

    /// Glides the camera to a new zoom and pan. Done frame by frame, because the island's
    /// drawing has the camera built in (SwiftUI can't interpolate a Canvas on its own).
    /// A new touch or camera move cancels a glide in progress.
    private func animateCamera(zoom toZoom: CGFloat, pan toPan: CGSize, duration: Double, easeOut: Bool = false, lock: Bool = false) {
        cameraGlide += 1
        cameraLocked = lock && !reduceMotion && duration > 0.05
        let token = cameraGlide
        let fromZoom = zoom, fromPan = pan
        zoomStart = toZoom
        panStart = toPan
        guard !reduceMotion, duration > 0.05 else { zoom = toZoom; pan = toPan; gliding = false; return }
        let glide = CameraGlide(fromZoom: fromZoom, toZoom: toZoom, fromPan: fromPan, toPan: toPan,
                                start: CACurrentMediaTime(), duration: duration, easeOut: easeOut)
        gliding = true
        Task {
            // Once per screen refresh, from the clock: the camera is always exactly where the glide
            // says at that moment, however the frames fall (a fixed sleep drifted against the
            // display and juddered, worst on 120 Hz screens).
            while cameraGlide == token {
                let now = CACurrentMediaTime()
                let c = glide.camera(at: now)
                zoom = c.zoom
                pan = c.pan
                if glide.isDone(at: now) { break }
                await FrameTicker.shared.nextFrame()
            }
            if cameraGlide == token { cameraLocked = false; gliding = false }
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
                zoom = min(Self.zoomCeiling, max(IslandLayout.minZoom, d.double(forKey: Keys.zoom)))
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
            zoom = min(Self.zoomCeiling, max(IslandLayout.minZoom, z)); pan = .zero
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

    /// Writes the camera (zoom, pan, turn) for next launch. Only when the app leaves the
    /// foreground or the island goes away: every UserDefaults write makes the home screen
    /// recompute (its `@AppStorage`), which with a full Bible is a visible hitch mid-gesture.
    private func saveCamera() {
        guard persistsCamera, cameraLoaded else { return }
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
                // A tap-to-zoom move is playing: touches wait until it lands.
                if cameraLocked { return }
                if !touchDown { touchBegan(at: value.startLocation, layout: layout) }
                // In edit mode, dragging a plot moves it (in whole tiles) instead of panning.
                if let drag = draggingPlot, let editing {
                    let g = layout.grid(CGPoint(x: value.location.x - pan.width, y: value.location.y - pan.height))
                    editing.onDrag(drag.key, Int((g.x - drag.start.x).rounded()), Int((g.y - drag.start.y).rounded()), false)
                    return
                }
                // While pinching, the pinch moves the camera (about the fingers); after a pinch, the
                // finger left on the screen doesn't pan until it lifts (its drag began before the
                // pinch, so it would jump).
                if pinchAnchor != nil || pinched { return }
                if !isPanning, !TapClassifier.isTap(translation: value.translation) { isPanning = true }
                if isPanning {
                    pan = clamp(CGSize(width: panStart.width + value.translation.width,
                                       height: panStart.height + value.translation.height), size: size)
                }
            }
            .onEnded { value in
                defer { pinched = false; touchDown = false; longPressed = false; draggingPlot = nil }
                if cameraLocked || !touchDown { return }
                if let drag = draggingPlot, let editing {
                    let g = layout.grid(CGPoint(x: value.location.x - pan.width, y: value.location.y - pan.height))
                    let moved = !TapClassifier.isTap(translation: value.translation)
                    editing.onDrag(drag.key, Int((g.x - drag.start.x).rounded()), Int((g.y - drag.start.y).rounded()), true)
                    if !moved { editing.onSelect(drag.key) }
                    return
                }
                if isPanning {
                    isPanning = false
                    // Keep gliding a little in the direction of the flick.
                    let carry = CGSize(width: (value.predictedEndTranslation.width - value.translation.width) * 0.6,
                                       height: (value.predictedEndTranslation.height - value.translation.height) * 0.6)
                    let target = clamp(CGSize(width: pan.width + carry.width, height: pan.height + carry.height), size: size)
                    if hypot(carry.width, carry.height) > 8 {
                        animateCamera(zoom: zoom, pan: target, duration: 0.55, easeOut: true)
                    } else {
                        panStart = pan
                    }
                } else if !pinched, !longPressed, TapClassifier.isTap(translation: value.translation) {
                    if let editing {
                        editing.onSelect(nil)
                    } else if let book = basket(at: value.location, layout: layout) {
                        onBasket?(book)
                    } else if onCrowd != nil, crowdTapped(value.location, layout: layout) {
                        onCrowd?()
                    } else if let c = character(at: value.location, layout: layout) {
                        speaking = (c.id, .now)
                    } else {
                        speaking = nil
                        let hit = IslandHitTester.hit(point: value.location, layout: layout, pan: pan, items: island.items)
                        onTap?(hit)
                        if hit == nil { groundTapped(at: value.location, size: size) }
                    }
                }
            }
    }

    /// Double-tap empty ground to zoom in there (or back out when already close in).
    private func groundTapped(at point: CGPoint, size: CGSize) {
        defer { lastGroundTap = (.now, point) }
        guard let last = lastGroundTap, Date.now.timeIntervalSince(last.time) < 0.35,
              hypot(point.x - last.at.x, point.y - last.at.y) < 30 else { return }
        lastGroundTap = nil
        let limit = maxZoom(size)
        let newZoom: CGFloat = zoom >= limit * 0.85 ? IslandLayout.minZoom : min(limit, zoom * 1.8)
        // Keep the tapped spot under the finger (zoom scales about the free area's centre).
        let centre = CGPoint(x: insets.leading + (size.width - insets.leading - insets.trailing) / 2,
                             y: insets.top + (size.height - insets.top - insets.bottom) / 2)
        let k = newZoom / zoom
        let newPan = CGSize(width: point.x - centre.x - (point.x - pan.width - centre.x) * k,
                            height: point.y - centre.y - (point.y - pan.height - centre.y) * k)
        let target = newZoom == IslandLayout.minZoom ? .zero : clampPan(newPan, zoom: newZoom, size: size)
        animateCamera(zoom: newZoom, pan: target, duration: 0.35)
    }

    /// Everyone on screen this frame (you, Bible characters, villagers, travellers), back to front.
    private static func people(feet: CGPoint, charW: CGFloat, charH: CGFloat, cast: [String],
                               shownCharacters: [String: LifeDirector.Shown], life: [LifeDirector.Shown], u: CGFloat) -> [IslandWorld.Figure] {
        var out: [IslandWorld.Figure] = []
        out.reserveCapacity(1 + cast.count + life.count)
        out.append(IslandWorld.Figure(id: "me", feet: feet, rect: CGRect(x: feet.x - charW / 2, y: feet.y - charH, width: charW, height: charH)))
        for id in cast {
            guard let f = shownCharacters[id] else { continue }
            let rect = CGRect(x: f.point.x - charH * 0.37, y: f.point.y - charH * 1.05, width: charH * 0.75, height: charH * 1.05)
            out.append(IslandWorld.Figure(id: "c:" + id, feet: f.point, rect: rect))
        }
        for f in life { out.append(IslandWorld.Figure(id: f.id, feet: f.point, rect: IslandLife.figureRect(f, u: u))) }
        return out.sorted { $0.feet.y < $1.feet.y }
    }

    /// The Bible characters showing this frame, by character id.
    private static func characterMap(_ shown: [LifeDirector.Shown]) -> [String: LifeDirector.Shown] {
        var out: [String: LifeDirector.Shown] = [:]
        for f in shown where f.id.hasPrefix("c:") && out[String(f.id.dropFirst(2))] == nil { out[String(f.id.dropFirst(2))] = f }
        return out
    }

    /// Bible characters for the level of detail (ids "c:<id>"); each stands still while talking.
    private func characterFigures(layout: IslandLayout, charH: CGFloat) -> [LifeDirector.Figure] {
        characters.map { c in
            let a = layout.point(c.home.x - c.radius, c.home.y - c.radius), b = layout.point(c.home.x + c.radius, c.home.y + c.radius)
            let l = layout.point(c.home.x - c.radius, c.home.y + c.radius), r = layout.point(c.home.x + c.radius, c.home.y - c.radius)
            let home = CGRect(x: l.x, y: a.y - charH * 1.1, width: r.x - l.x, height: b.y - a.y + charH * 1.2)
            let talking = speaking.map { $0.id == c.id && Date.now.timeIntervalSince($0.since) < 7 } ?? false
            return LifeDirector.Figure(id: "c:\(c.id)", home: home,
                                       position: { t in let g = c.position(at: t); return layout.point(g.x, g.y) }, frozen: talking)
        }
    }

    /// Collect All: the baskets on screen fly into the button (nearest first); the rest were
    /// simply collected. With Reduce Motion nothing flies.
    private func startFlight(_ f: CollectFlight, layout: IslandLayout, size: CGSize) {
        let view = CGRect(origin: .zero, size: size)
        let target = CGPoint(x: collectTarget.midX - globalOrigin.x, y: collectTarget.midY - globalOrigin.y)
        var onScreen: [(grid: CGPoint, kind: ProduceKind, count: Int, distance: CGFloat)] = []
        for e in f.entries {
            guard let index = island.placeIndex(e.bookID) else { continue }
            let item = island.items[index]
            let s = IslandLife.basketPoint(layout.point(item.gx, item.gy), u: layout.u, time: 0)
            guard view.contains(s) else { continue }
            onScreen.append((CGPoint(x: item.gx, y: item.gy), e.kind, e.amount, hypot(s.x - target.x, s.y - target.y)))
        }
        let sprites = reduceMotion ? [] : CollectFlightPlan.sprites(onScreen.sorted { $0.distance < $1.distance }.map { ($0.grid, $0.kind, $0.count) })
        guard !sprites.isEmpty else { onCollectLanded?(); return }
        let start = Date.now
        flight = (sprites, start)
        Task {
            try? await Task.sleep(for: .seconds(CollectFlightPlan.length(sprites)))
            if flight?.start == start { flight = nil }
            onCollectLanded?()
        }
    }

    /// The basket under a tap, if any (generous target).
    private func basket(at location: CGPoint, layout: IslandLayout) -> String? {
        guard layout.u >= IslandLife.minimumBasketU else { return nil }
        let p = CGPoint(x: location.x - pan.width, y: location.y - pan.height)
        let t = Date.now.timeIntervalSinceReferenceDate
        return life.baskets.first { b in
            let s = IslandLife.basketPoint(layout.point(b.point.x, b.point.y), u: layout.u, time: t)
            return hypot(s.x - p.x, s.y - p.y) < max(24, 18 * layout.u)
        }?.bookID
    }

    /// A tap on the plaza's crowd.
    private func crowdTapped(_ location: CGPoint, layout: IslandLayout) -> Bool {
        guard life.villagers.contains(where: { $0.id.hasPrefix("crowd") }) else { return false }
        let g = layout.grid(CGPoint(x: location.x - pan.width, y: location.y - pan.height))
        return CGRect(x: IslandPlacer.start.x, y: IslandPlacer.start.y, width: IslandPlacer.start.size, height: IslandPlacer.start.size)
            .insetBy(dx: -0.2, dy: -0.2).contains(g)
    }

    /// The character under a tap, if any (44pt minimum target).
    private func character(at location: CGPoint, layout: IslandLayout) -> IslandCharacter? {
        let charH = Self.characterHeight * layout.u
        let p = CGPoint(x: location.x - pan.width, y: location.y - pan.height)
        let candidates = characters.compactMap { c -> HitCandidate<String>? in
            guard let time = director.peek("c:\(c.id)"), director.opacity("c:\(c.id)") > 0.5 else { return nil }
            let g = c.position(at: time)
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
        gliding = false
        touchID += 1
        let id = touchID
        let p = CGPoint(x: location.x - pan.width, y: location.y - pan.height)
        let g = layout.grid(p)
        if editing != nil {
            // The plot under the finger, or the one whose building was touched.
            let hitKey = IslandHitTester.hit(point: location, layout: layout, pan: pan, items: island.items)
                .flatMap { island.items[$0].plotKey }
            let plots = island.allPlots
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

    /// The furthest in you can zoom on this island, at this size.
    private func maxZoom(_ size: CGSize) -> CGFloat { IslandLayout.maxZoom(island: island, size: size, insets: insets) }

    /// Saved zooms are trusted only up to this before the view's size is known.
    static let zoomCeiling: CGFloat = 80

    /// Pinch to zoom about the point between your fingers. Past either limit it gives a little
    /// (rubber-band), then eases back when you let go.
    private func zoomGesture(size: CGSize) -> some Gesture {
        MagnifyGesture()
            .onChanged { value in pinchChanged(magnification: value.magnification, at: value.startLocation, size: size) }
            .onEnded { _ in pinchEnded(size: size) }
    }

    /// A pinch moved: zoom about the point between the fingers.
    private func pinchChanged(magnification: CGFloat, at location: CGPoint, size: CGSize) {
        if cameraLocked { return }
        pinched = true
        if pinchAnchor == nil {
            cameraGlide += 1
            gliding = false
            isPanning = false
            pinchAnchor = location
            pinchFrom = (zoom, pan)
        }
        guard let anchor = pinchAnchor, let from = pinchFrom else { return }
        // Smoothed (a wobbling finger doesn't twitch the island), then the pan that keeps the
        // spot between the fingers exactly where it is. Nothing else moves the camera meanwhile;
        // it's kept inside its limits once the fingers lift.
        let limit = maxZoom(size)
        let target = IslandLayout.clampedZoom(Self.rubberBand(from.zoom * magnification, min: IslandLayout.minZoom, max: limit), maxZoom: limit)
        let z = PinchSmoothing.next(current: zoom, target: target)
        zoom = z
        pan = Self.panKeeping(anchor, from: from, toZoom: z, centre: freeCentre(size))
    }


    /// The pinch ended: settle inside the limits.
    private func pinchEnded(size: CGSize) {
        defer { pinchAnchor = nil; pinchFrom = nil }
        guard pinchAnchor != nil else { return }
        let limit = maxZoom(size)
        let settled = min(limit, max(IslandLayout.minZoom, zoom))
        if settled != zoom, let anchor = pinchAnchor, let from = pinchFrom {
            // Ease back inside the limit, still about the fingers.
            let target = clampPan(Self.panKeeping(anchor, from: from, toZoom: settled, centre: freeCentre(size)), zoom: settled, size: size)
            animateCamera(zoom: settled, pan: settled == IslandLayout.minZoom ? clampPan(target, zoom: settled, size: size) : target,
                          duration: 0.35, easeOut: true)
        } else {
            let clamped = clamp(pan, size: size)
            if clamped != pan { animateCamera(zoom: zoom, pan: clamped, duration: 0.3, easeOut: true) } else { zoomStart = zoom; panStart = pan }
        }
    }

    /// The middle of the free area (zoom scales about it).
    private func freeCentre(_ size: CGSize) -> CGPoint {
        CGPoint(x: insets.leading + (size.width - insets.leading - insets.trailing) / 2,
                y: insets.top + (size.height - insets.top - insets.bottom) / 2)
    }

    /// The pan that keeps `anchor` (a point on screen) over the same spot of the island when
    /// zooming from `from` to `toZoom`.
    static func panKeeping(_ anchor: CGPoint, from: (zoom: CGFloat, pan: CGSize), toZoom z: CGFloat, centre: CGPoint) -> CGSize {
        let k = z / from.zoom
        return CGSize(width: anchor.x - centre.x - (anchor.x - from.pan.width - centre.x) * k,
                      height: anchor.y - centre.y - (anchor.y - from.pan.height - centre.y) * k)
    }

    /// Past a limit, zoom gives only a little (and less the further you push).
    static func rubberBand(_ z: CGFloat, min lo: CGFloat, max hi: CGFloat) -> CGFloat {
        if z > hi { return hi * pow(z / hi, 0.25) }
        if z < lo { return lo * pow(z / lo, 0.25) }
        return z
    }

    /// A two-finger twist of more than 30° turns the island a quarter turn that way.
    private var twistGesture: some Gesture {
        RotateGesture(minimumAngleDelta: .degrees(8))
            .onChanged { _ in pinched = true }
            .onEnded { value in
                guard !cameraLocked else { return }
                let degrees = value.rotation.degrees
                if degrees > 30 { turn(by: 1) } else if degrees < -30 { turn(by: -1) }
            }
    }

    /// Keeps the island on screen however far you zoom.
    private func clamp(_ p: CGSize, size: CGSize) -> CGSize { clampPan(p, zoom: zoom, size: size) }

    private func clampPan(_ p: CGSize, zoom: CGFloat, size: CGSize, slack: CGFloat = 0) -> CGSize {
        let z = max(1, zoom)
        // Always far enough to centre any Place (tapping one, Find me, a reveal), at any turn.
        let reach = IslandCamera.reach(island: island, size: size, insets: insets, zoom: z)
        let maxX = max((z - 1) * size.width / 2 + size.width * 0.25, reach.width) + slack
        let maxY = max((z - 1) * size.height / 2 + size.height * 0.25, reach.height) + slack
        return CGSize(width: min(maxX, max(-maxX, p.width)), height: min(maxY, max(-maxY, p.height)))
    }

    /// Eases the view so the selected item sits in the middle of the free area, above the card
    /// that opens for it (the card covers the lower half, so "middle" is a third of the way down).
    private func centre(on item: Island.Item, size: CGSize) {
        let target = IslandCamera.freeCentre(size: size, insets: insets, fraction: 0.35)
        animateCamera(zoom: zoom, pan: IslandCamera.pan(toCentre: IslandCamera.focus(of: item, in: island), island: island,
                                                        size: size, insets: insets, zoom: zoom, quarter: quarter, target: target),
                      duration: 0.45)
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
    static func drawEditGrid(_ c: inout GraphicsContext, island: Island, layout: IslandLayout, editing: IslandEditing) {
        let grid = Path { p in
            for t in island.tiles {
                p.addLines([layout.point(CGFloat(t.x), CGFloat(t.y)), layout.point(CGFloat(t.x + 1), CGFloat(t.y)),
                            layout.point(CGFloat(t.x + 1), CGFloat(t.y + 1)), layout.point(CGFloat(t.x), CGFloat(t.y + 1))])
                p.closeSubpath()
            }
        }
        c.stroke(grid, with: .color(Color.primaryBrown.opacity(0.12)), lineWidth: 0.6)
        for plot in island.allPlots {
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

    /// Extras in edit mode: a ring under each, green when picked, red where it can't go.
    static func drawExtraRings(_ c: inout GraphicsContext, island: Island, layout: IslandLayout, editing: IslandEditing) {
        for item in island.items {
            guard case .extra(let id) = item.source else { continue }
            let key = "extra:\(id)"
            let base = layout.point(item.gx, item.gy)
            let w = layout.scale * 0.9
            let ring = Path(ellipseIn: CGRect(x: base.x - w / 2, y: base.y - w * 0.22, width: w, height: w * 0.44))
            if island.conflicts.contains(key) {
                c.fill(ring, with: .color(Color.red.opacity(0.22))); c.stroke(ring, with: .color(Color.red.opacity(0.8)), lineWidth: 2)
            } else if editing.selected == key {
                c.fill(ring, with: .color(Color.green.opacity(0.16))); c.stroke(ring, with: .color(Color(hex: "#5E8C4A")), lineWidth: 2)
            } else {
                c.stroke(ring, with: .color(Color.primaryBrown.opacity(0.35)), style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
            }
        }
    }

    static func drawHighlight(_ c: inout GraphicsContext, _ item: Island.Item, layout: IslandLayout) {
        c.fill(Path(ellipseIn: highlightRect(item, layout: layout)), with: .color(Color.wheat.opacity(0.55)))
    }

    /// The selection ring: an ellipse on the ground around the item's base.
    static func highlightRect(_ item: Island.Item, layout: IslandLayout) -> CGRect {
        let base = layout.point(item.gx, item.gy)
        let w = max(item.footprint.width, 0.5) * layout.scale * 2.2
        return CGRect(x: base.x - w / 2, y: base.y - w * 0.22, width: w, height: w * 0.44)
    }

    /// The things that stand over the selection ring (the selected building and its neighbours),
    /// back to front: drawn again over it, inside the ring only, when the buildings are baked into
    /// the ground below it (far out), so the ring stays on the ground under them.
    static func itemsOverRing(_ item: Island.Item, ordered: [Island.Item], layout: IslandLayout) -> [Island.Item] {
        let ring = highlightRect(item, layout: layout)
        return ordered.filter { IslandWorld.pictureRect($0, layout: layout).intersects(ring) }
    }

    #if DEBUG
    /// `-showHitBoxes`: outlines each item's tap area (drawn bounds in red, ground in blue,
    /// 44pt minimum in grey) to diagnose taps that miss.
    static let showHitBoxes = ProcessInfo.processInfo.arguments.contains("-showHitBoxes")

    static func drawHitBoxes(_ c: inout GraphicsContext, island: Island, layout: IslandLayout) {
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
        // Just in front of its door (bigger buildings, like the Library, have the door further out).
        let out = max(0.62, item.footprint.width / 2 + 0.15)
        let door = CGPoint(x: item.gx + out, y: item.gy + out)
        // Right up to it: its Place fills most of the screen's width, centred, in one smooth eased
        // move of position and zoom together; touches wait until it lands.
        let newZoom = IslandCamera.visitZoom(for: item, in: island, size: size, insets: insets, quarter: quarter)
        let walkTime = min(2.2, max(0.6, hypot(door.x - spot.x, door.y - spot.y) / 2.2))
        animateCamera(zoom: newZoom, pan: IslandCamera.pan(toCentre: IslandCamera.focus(of: item, in: island), island: island,
                                                           size: size, insets: insets, zoom: newZoom, quarter: quarter),
                      duration: Self.visitGlide, lock: true)
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

    /// The "see it built" moment. For each beat: the camera glides to the Place, the new piece
    /// rises with a bounce, dust and sparkles (or a field or village spreads), the caption shows,
    /// your character walks over to look; then the next beat, and the camera eases back.
    private func startReveal() {
        guard !reveal.isEmpty else { return }
        revealToken += 1
        let token = revealToken
        let steps = reveal
        let before = (zoom: zoomStart, pan: panStart)
        withAnimation(.easeInOut(duration: 0.3)) { overrides = revealInitial }
        Task {
            // Let the reading sheet slide away first.
            try? await Task.sleep(for: .milliseconds(350))
            for step in steps {
                guard revealToken == token else { return }
                let focus = island.items.indices.contains(step.focus) ? island.items[step.focus] : nil
                if let focus, !reduceMotion, persistsCamera, viewSize != .zero {
                    let newZoom = max(zoom, step.kind == .combined ? 2 : 2.6)
                    animateCamera(zoom: newZoom, pan: IslandCamera.pan(toCentre: IslandCamera.focus(of: focus, in: island), island: island,
                                                                       size: viewSize, insets: insets, zoom: newZoom, quarter: quarter),
                                  duration: 0.6)
                    try? await Task.sleep(for: .milliseconds(750))
                }
                guard revealToken == token else { return }
                beat = (step, .now)
                onRevealStep?(step)
                if let focus, !reduceMotion {
                    Task {
                        try? await Task.sleep(for: .milliseconds(700))
                        guard revealToken == token else { return }
                        await walk(to: CGPoint(x: focus.gx + 0.6, y: focus.gy + 0.5), speed: 1.8, maxDuration: 1.4)
                    }
                }
                try? await Task.sleep(for: .seconds(reduceMotion ? 1.6 : step.duration - 0.75))
                guard revealToken == token else { return }
                for change in step.changes { overrides[change.index] = change.to }
                beat = nil
            }
            guard revealToken == token else { return }
            finishReveal(cameraBack: before, duration: 0.7)
        }
    }

    private func skipReveal() {
        revealToken += 1
        finishReveal(cameraBack: nil, duration: 0.3)
    }

    private func finishReveal(cameraBack: (zoom: CGFloat, pan: CGSize)?, duration: Double) {
        beat = nil
        withAnimation(.easeOut(duration: 0.3)) { overrides = [:] }
        onRevealStep?(nil)
        if let cameraBack, visit == nil, persistsCamera { animateCamera(zoom: cameraBack.zoom, pan: cameraBack.pan, duration: duration) }
    }

    /// Draws one beat's changing items: new ones rise from the ground with an overshoot and a
    /// puff of dust; growing ones spread from their old size to the new one.
    private static func drawBeat(_ c: inout GraphicsContext, _ step: RevealStep, elapsed: Double, island: Island, layout: IslandLayout) {
        let big = step.kind != .grow
        let t = min(1, max(0, (elapsed - 0.15) / (big ? 0.9 : 0.7)))
        for change in step.changes.sorted(by: { a, b in
            let ia = island.items[a.index], ib = island.items[b.index]
            return layout.depth(ia.gx, ia.gy) < layout.depth(ib.gx, ib.gy)
        }) where island.items.indices.contains(change.index) {
            var item = island.items[change.index]
            let e = 1 - pow(1 - t, 3)
            if item.kind == .library {
                // The new stage rises out of the old: the old fades as the new one grows up.
                if t < 1 {
                    var old = item
                    old.growth = change.from
                    var g = c
                    g.opacity = 1 - t
                    IslandPainter.drawItem(&g, old, layout: layout)
                }
                guard t > 0 else { continue }
                item.growth = change.to
                var g = c
                g.translateBy(x: 0, y: t < 1 ? (1 - t) * 24 * layout.u : 0)
                g.opacity = min(1, t * 2)
                IslandPainter.drawItem(&g, item, layout: layout, scale: t < 1 ? overshoot(t) : 1)
            } else if change.from == 0 {
                // Pops up: rises out of the ground with a little bounce.
                guard t > 0 else { continue }
                item.growth = change.to
                var g = c
                g.translateBy(x: 0, y: t < 1 ? (1 - t) * 14 * layout.u : 0)
                IslandPainter.drawItem(&g, item, layout: layout, scale: t < 1 ? overshoot(t) : 1)
            } else {
                // Spreads outward.
                item.growth = change.from + (change.to - change.from) * CGFloat(e)
                IslandPainter.drawItem(&c, item, layout: layout)
            }
            drawDust(&c, at: layout.point(item.gx, item.gy), progress: (elapsed - 0.15) / 0.45, u: layout.u,
                     sparkles: change.index == step.focus, burst: step.kind == .library ? 3 : big ? 2 : 1,
                     spread: item.kind == .library ? item.span / 2 : 1)
        }
    }

    /// A puff of dust at the base while something builds in, and sparkles for the focus.
    private static func drawDust(_ c: inout GraphicsContext, at base: CGPoint, progress: Double, u: CGFloat, sparkles: Bool,
                                 burst: Int = 1, spread: CGFloat = 1) {
        guard progress > 0, progress < 1.6 + Double(burst - 1) * 0.8 else { return }
        let t = CGFloat(min(1, progress / 1.6))
        let puffs = spread > 1 ? 9 : 5
        for i in 0..<puffs {
            let a = CGFloat(i) / CGFloat(puffs) * .pi * 2
            let r = (6 + 16 * t) * u * max(1, spread)
            let p = CGPoint(x: base.x + cos(a) * r, y: base.y + sin(a) * r * 0.45)
            let s = (5 + 4 * t) * u
            c.fill(Path(ellipseIn: CGRect(x: p.x - s, y: p.y - s * 0.6, width: 2 * s, height: 1.2 * s)),
                   with: .color(Earthy.stone.opacity(Double(0.7 * (1 - t)))))
        }
        guard sparkles else { return }
        for i in 0..<(6 * burst) {
            let x = base.x + CGFloat(i - 3) * 6 * u + sin(CGFloat(i) * 1.7) * 4 * u
            let y = base.y - (18 + CGFloat(i % 3) * 8 + 30 * t) * u
            let s = (2.4 + CGFloat(i % 2)) * u
            let star = Path { p in
                p.move(to: CGPoint(x: x, y: y - s)); p.addLine(to: CGPoint(x: x + s * 0.3, y: y - s * 0.3))
                p.addLine(to: CGPoint(x: x + s, y: y)); p.addLine(to: CGPoint(x: x + s * 0.3, y: y + s * 0.3))
                p.addLine(to: CGPoint(x: x, y: y + s)); p.addLine(to: CGPoint(x: x - s * 0.3, y: y + s * 0.3))
                p.addLine(to: CGPoint(x: x - s, y: y)); p.addLine(to: CGPoint(x: x - s * 0.3, y: y - s * 0.3)); p.closeSubpath()
            }
            c.fill(star, with: .color(Earthy.gold.opacity(Double(1 - t))))
        }
    }
}
