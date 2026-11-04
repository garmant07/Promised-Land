import SpriteKit
import UIKit

/// Saved camera position (scene coordinates) and zoom.
struct CameraState: Codable, Equatable {
    var x: Double
    var y: Double
    var scale: Double

    static let `default`: CameraState = {
        let p = Iso.scene(56, 40) // between the Promised Land and Jerusalem
        return CameraState(x: p.x, y: p.y, scale: 2.0)
    }()

    static func load() -> CameraState? {
        guard let data = UserDefaults.standard.data(forKey: StorageKeys.worldCamera) else { return nil }
        return try? JSONDecoder().decode(CameraState.self, from: data)
    }

    func save() {
        if let data = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(data, forKey: StorageKeys.worldCamera)
        }
    }
}

/// Lets a texture cross into a main-actor task after an off-thread preload.
private struct TextureBox: @unchecked Sendable {
    let texture: SKTexture
}

/// The isometric world, rendered with SpriteKit.
final class WorldScene: SKScene {

    // MARK: Public hooks

    /// Called when the visible area changes (throttled), with the visible rect in scene space.
    var onViewportChange: ((CGRect) -> Void)?
    /// Called when a landmark is tapped, with its book id.
    var onSelectLandmark: ((String) -> Void)?
    /// Called when a connection road is tapped, with the connection id.
    var onSelectConnection: ((String) -> Void)?
    /// Called when a story object (ChapterLandmarks) is tapped, with its id.
    var onSelectStoryObject: ((String) -> Void)?

    // MARK: Layers

    let cameraNode = SKCameraNode()
    let terrainLayer = SKNode()
    let objectLayer = SKNode()
    let overlayLayer = SKNode()
    let landmarkLayer = LandmarkLayer()
    let fogLayer = FogLayer()
    let connectionLayer = ConnectionLayer()
    let chapterObjectLayer = ChapterObjectLayer()
    let decorationLayer = DecorationLayer()
    let characterLayer = CharacterLayer()
    let ambientLayer = AmbientLayer()

    // MARK: Progress

    private var progress: GameProgress?
    private var appliedProgress = false
    private var moments: [Moment] = []
    private var isOnScreen = false

    // MARK: Terrain chunks

    private(set) var terrain: TerrainModel?
    private let chunkSize = CGSize(width: 1024, height: 512)
    private var chunkOrigin = CGPoint.zero
    private var chunkColumns = 0
    private var chunkRows = 0
    private var chunkSprites: [Int: SKSpriteNode] = [:]
    private var chunkSpriteScale: [Int: CGFloat] = [:]
    private var lowTextures: [Int: SKTexture] = [:]
    private var detailTextures: [Int: (scale: CGFloat, texture: SKTexture, lastUsed: TimeInterval)] = [:]
    private var pending: Set<String> = []
    private let lowScale: CGFloat = 0.4
    private let maxDetailTextures = 30

    let mapBounds = Iso.sceneBounds(width: WorldData.mapWidth, height: WorldData.mapHeight)

    // MARK: Camera state

    let minZoom: CGFloat = 0.45
    let maxZoom: CGFloat = 4.0
    private var velocity = CGVector.zero
    private var lastUpdate: TimeInterval = 0
    private var needsChunkRefresh = true
    private var lastViewportReport: TimeInterval = 0
    private var lastReportedViewport = CGRect.zero
    private var didConfigure = false
    private var decorationsPending = false

    // MARK: Setup

    override init(size: CGSize) {
        super.init(size: size)
        scaleMode = .resizeFill
        backgroundColor = UIColor(red: RGB.ocean.r, green: RGB.ocean.g, blue: RGB.ocean.b, alpha: 1)
        anchorPoint = CGPoint(x: 0.5, y: 0.5)
    }

    convenience override init() { self.init(size: CGSize(width: 390, height: 844)) }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    override func didMove(to view: SKView) {
        super.didMove(to: view)
        installGestures(in: view)
        guard !didConfigure else { return }
        didConfigure = true

        addChild(terrainLayer)
        addChild(objectLayer)
        objectLayer.addChild(connectionLayer)
        objectLayer.addChild(decorationLayer)
        objectLayer.addChild(landmarkLayer)
        objectLayer.addChild(chapterObjectLayer)
        objectLayer.addChild(characterLayer)
        addChild(fogLayer)
        addChild(landmarkLayer.labelLayer)
        addChild(ambientLayer)
        addChild(overlayLayer)
        overlayLayer.zPosition = 10_000
        addChild(cameraNode)
        camera = cameraNode

        var state = CameraState.load() ?? .default
        #if DEBUG
        state = DebugSeed.cameraOverride() ?? state
        #endif
        cameraNode.position = CGPoint(x: state.x, y: state.y)
        cameraNode.setScale(CGFloat(state.scale))
        clampCamera()

        chunkOrigin = CGPoint(x: mapBounds.minX - 256, y: mapBounds.minY - 256)
        chunkColumns = Int(ceil((mapBounds.width + 512) / chunkSize.width))
        chunkRows = Int(ceil((mapBounds.height + 512) / chunkSize.height))

        NotificationCenter.default.addObserver(self, selector: #selector(saveCamera),
                                               name: UIApplication.willResignActiveNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(resetCamera),
                                               name: .resetWorldCamera, object: nil)

        if let progress { apply(progress) }
        landmarkLayer.updateLabels(zoom: cameraNode.xScale)

        let inputs = TerrainInputs.fromWorldData()
        Task.detached(priority: .userInitiated) { [weak self] in
            let model = TerrainModel.generate(inputs)
            await self?.terrainReady(model)
        }
    }

    private func terrainReady(_ model: TerrainModel) {
        terrain = model
        needsChunkRefresh = true
        decorationLayer.build(model)
        if let progress {
            decorationLayer.setFogged(Set(WorldData.regions.map(\.id).filter { !progress.isRegionRevealed($0) }), animated: false)
        }
        decorationsPending = decorationLayer.update(visible: visibleRect())
        syncRoads()
        playNextMoment()
        // Low-detail textures for the whole map, so panning never shows a gap.
        let rects = (0..<(chunkColumns * chunkRows)).map { ($0, chunkRect($0)) }
        let scale = lowScale
        Task.detached(priority: .utility) { [weak self] in
            for (index, rect) in rects {
                guard let image = TerrainRenderer.render(model, rect: rect, scale: scale) else { continue }
                await self?.installLowTexture(image, index: index)
            }
        }
    }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        clampCamera()
        needsChunkRefresh = true
    }

    // MARK: Frame loop

    override func update(_ currentTime: TimeInterval) {
        let dt = lastUpdate == 0 ? 1.0 / 60 : min(0.05, currentTime - lastUpdate)
        lastUpdate = currentTime

        if hypot(velocity.dx, velocity.dy) > 4 {
            cameraNode.position.x += velocity.dx * dt
            cameraNode.position.y += velocity.dy * dt
            let decay = exp(-5.0 * dt)
            velocity.dx *= decay
            velocity.dy *= decay
            clampCamera()
            if hypot(velocity.dx, velocity.dy) <= 4 {
                velocity = .zero
                saveCamera()
            }
        }

        #if DEBUG
        autopan(currentTime: currentTime)
        #endif

        let viewport = visibleRect()
        characterLayer.updateDepths()
        ambientLayer.update(dt: dt, visible: viewport, zoom: cameraNode.xScale, terrain: terrain)
        if viewport != lastReportedViewport {
            needsChunkRefresh = true
            if currentTime - lastViewportReport > 0.1 {
                lastViewportReport = currentTime
                lastReportedViewport = viewport
                onViewportChange?(viewport)
                viewportDidChange(viewport)

            }
        }
        if needsChunkRefresh {
            needsChunkRefresh = false
            refreshChunks(currentTime: currentTime)
        }
        if decorationsPending {
            decorationsPending = decorationLayer.update(visible: viewport)
        }

    }

    private func viewportDidChange(_ viewport: CGRect) {
        landmarkLayer.updateLabels(zoom: cameraNode.xScale)
        decorationsPending = decorationLayer.update(visible: viewport)
    }

    func visibleRect() -> CGRect {
        let w = size.width * cameraNode.xScale, h = size.height * cameraNode.yScale
        return CGRect(x: cameraNode.position.x - w / 2, y: cameraNode.position.y - h / 2, width: w, height: h)
    }

    // MARK: Chunks

    private func chunkRect(_ index: Int) -> CGRect {
        let col = index % chunkColumns, row = index / chunkColumns
        return CGRect(x: chunkOrigin.x + CGFloat(col) * chunkSize.width,
                      y: chunkOrigin.y + CGFloat(row) * chunkSize.height,
                      width: chunkSize.width, height: chunkSize.height)
    }

    private func desiredDetailScale() -> CGFloat? {
        let zoom = cameraNode.xScale
        if zoom < 0.9 { return 1.8 }
        if zoom < 2.2 { return 1.0 }
        return 0.6
    }

    private func refreshChunks(currentTime: TimeInterval) {
        guard let terrain else { return }
        let view = visibleRect().insetBy(dx: -chunkSize.width * 0.5, dy: -chunkSize.height * 0.5)
        let keep = view.insetBy(dx: -chunkSize.width, dy: -chunkSize.height)
        let detail = desiredDetailScale()

        var visible: Set<Int> = []
        let c0 = max(0, Int(floor((view.minX - chunkOrigin.x) / chunkSize.width)))
        let c1 = min(chunkColumns - 1, Int(floor((view.maxX - chunkOrigin.x) / chunkSize.width)))
        let r0 = max(0, Int(floor((view.minY - chunkOrigin.y) / chunkSize.height)))
        let r1 = min(chunkRows - 1, Int(floor((view.maxY - chunkOrigin.y) / chunkSize.height)))
        if c0 <= c1, r0 <= r1 {
            for row in r0...r1 { for col in c0...c1 { visible.insert(row * chunkColumns + col) } }
        }

        for index in visible {
            var best: (CGFloat, SKTexture)? = lowTextures[index].map { (lowScale, $0) }
            if let cached = detailTextures[index] {
                detailTextures[index]?.lastUsed = currentTime
                if detail != nil { best = (cached.scale, cached.texture) }
            }
            if let detail, (detailTextures[index]?.scale ?? 0) < detail {
                requestDetail(index: index, scale: detail, model: terrain)
            }
            guard let (scale, texture) = best else { continue }
            if let sprite = chunkSprites[index] {
                if chunkSpriteScale[index] != scale {
                    sprite.texture = texture
                    chunkSpriteScale[index] = scale
                }
            } else {
                let sprite = SKSpriteNode(texture: texture, size: chunkSize)
                sprite.anchorPoint = .zero
                sprite.position = chunkRect(index).origin
                sprite.zPosition = 0
                terrainLayer.addChild(sprite)
                chunkSprites[index] = sprite
                chunkSpriteScale[index] = scale
            }
        }

        // Drop sprites well outside the view.
        for (index, sprite) in chunkSprites where !keep.intersects(chunkRect(index)) {
            sprite.removeFromParent()
            chunkSprites[index] = nil
            chunkSpriteScale[index] = nil
        }

        // Keep the detail cache small, evicting what hasn't been seen for longest.
        if detailTextures.count > maxDetailTextures {
            let evict = detailTextures.filter { !visible.contains($0.key) }
                .sorted { $0.value.lastUsed < $1.value.lastUsed }
                .prefix(detailTextures.count - maxDetailTextures)
            for (index, _) in evict { detailTextures[index] = nil }
        }
    }

    private func requestDetail(index: Int, scale: CGFloat, model: TerrainModel) {
        let key = "\(index)@\(scale)"
        guard !pending.contains(key) else { return }
        pending.insert(key)
        let rect = chunkRect(index)
        Task.detached(priority: .userInitiated) { [weak self] in
            let image = TerrainRenderer.render(model, rect: rect, scale: scale)
            await self?.installDetailTexture(image, index: index, scale: scale, key: key)
        }
    }

    private func installLowTexture(_ image: RenderedImage, index: Int) {
        let box = TextureBox(texture: SKTexture(cgImage: image.image))
        // Upload to the GPU off the main thread, then swap in.
        Task { [weak self] in
            await box.texture.preload()
            guard let self else { return }
            self.lowTextures[index] = box.texture
            self.needsChunkRefresh = true
        }
    }

    private func installDetailTexture(_ image: RenderedImage?, index: Int, scale: CGFloat, key: String) {
        guard let image else { pending.remove(key); return }
        let box = TextureBox(texture: SKTexture(cgImage: image.image))
        Task { [weak self] in
            await box.texture.preload()
            guard let self else { return }
            self.pending.remove(key)
            if let existing = self.detailTextures[index], existing.scale >= scale { return }
            self.detailTextures[index] = (scale, box.texture, self.lastUpdate)
            self.needsChunkRefresh = true
        }
    }

    // MARK: Camera

    func clampCamera() {
        let zoom = min(maxZoom, max(minZoom, cameraNode.xScale))
        cameraNode.setScale(zoom)
        let halfW = size.width * zoom / 2, halfH = size.height * zoom / 2
        let bounds = mapBounds.insetBy(dx: -80, dy: -80)
        var p = cameraNode.position
        p.x = bounds.width > halfW * 2 ? min(max(p.x, bounds.minX + halfW), bounds.maxX - halfW) : bounds.midX
        p.y = bounds.height > halfH * 2 ? min(max(p.y, bounds.minY + halfH), bounds.maxY - halfH) : bounds.midY
        if p != cameraNode.position { cameraNode.position = p }
    }

    /// Smoothly moves the camera to a scene point, optionally changing zoom.
    func flyTo(_ point: CGPoint, zoom: CGFloat? = nil, duration: TimeInterval = 0.6) {
        velocity = .zero
        cameraNode.removeAction(forKey: "fly")
        let targetZoom = min(maxZoom, max(minZoom, zoom ?? cameraNode.xScale))
        let move = SKAction.move(to: point, duration: duration)
        let scale = SKAction.scale(to: targetZoom, duration: duration)
        let group = SKAction.group([move, scale])
        group.timingMode = .easeInEaseOut
        cameraNode.run(.sequence([group, .run { [weak self] in
            self?.clampCamera()
            self?.saveCamera()
        }]), withKey: "fly")
    }

    func flyTo(grid: CGPoint, zoom: CGFloat? = nil) {
        flyTo(Iso.scene(grid), zoom: zoom)
    }

    @objc func saveCamera() {
        CameraState(x: cameraNode.position.x, y: cameraNode.position.y, scale: cameraNode.xScale).save()
    }

    @objc private func resetCamera() {
        let state = CameraState.default
        flyTo(CGPoint(x: state.x, y: state.y), zoom: state.scale)
    }

    // MARK: Gestures

    private var installedGestureView: SKView?

    private func installGestures(in view: SKView) {
        guard installedGestureView !== view else { return }
        installedGestureView = view
        let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        pan.maximumNumberOfTouches = 1
        let pinch = UIPinchGestureRecognizer(target: self, action: #selector(handlePinch(_:)))
        let doubleTap = UITapGestureRecognizer(target: self, action: #selector(handleDoubleTap(_:)))
        doubleTap.numberOfTapsRequired = 2
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        tap.require(toFail: doubleTap)
        [pan, pinch, doubleTap, tap].forEach(view.addGestureRecognizer)
    }

    @objc private func handlePan(_ g: UIPanGestureRecognizer) {
        guard let view = g.view else { return }
        switch g.state {
        case .began:
            cameraNode.removeAction(forKey: "fly")
            velocity = .zero
        case .changed:
            let t = g.translation(in: view)
            g.setTranslation(.zero, in: view)
            cameraNode.position.x -= t.x * cameraNode.xScale
            cameraNode.position.y += t.y * cameraNode.yScale
            clampCamera()
        case .ended, .cancelled:
            let v = g.velocity(in: view)
            velocity = CGVector(dx: -v.x * cameraNode.xScale, dy: v.y * cameraNode.yScale)
            if hypot(velocity.dx, velocity.dy) <= 4 { saveCamera() }
        default: break
        }
    }

    @objc private func handlePinch(_ g: UIPinchGestureRecognizer) {
        guard let view = g.view else { return }
        switch g.state {
        case .began:
            cameraNode.removeAction(forKey: "fly")
            velocity = .zero
        case .changed:
            let location = g.location(in: view)
            let before = convertPoint(fromView: location)
            let zoom = min(maxZoom, max(minZoom, cameraNode.xScale / g.scale))
            g.scale = 1
            cameraNode.setScale(zoom)
            let after = convertPoint(fromView: location)
            cameraNode.position.x += before.x - after.x
            cameraNode.position.y += before.y - after.y
            clampCamera()
        case .ended, .cancelled:
            saveCamera()
        default: break
        }
    }

    @objc private func handleDoubleTap(_ g: UITapGestureRecognizer) {
        guard let view = g.view else { return }
        let point = convertPoint(fromView: g.location(in: view))
        let zoom = cameraNode.xScale <= minZoom * 1.2 ? 1.2 : cameraNode.xScale / 2
        flyTo(point, zoom: zoom, duration: 0.4)
    }

    @objc private func handleTap(_ g: UITapGestureRecognizer) {
        guard let view = g.view else { return }
        handleTap(at: convertPoint(fromView: g.location(in: view)))
    }

    private func handleTap(at scenePoint: CGPoint) {
        if let character = characterLayer.character(at: scenePoint) {
            characterLayer.speak(character, zoom: cameraNode.xScale)
        } else if let id = chapterObjectLayer.object(at: scenePoint) {
            onSelectStoryObject?(id)
        } else if let bookID = landmarkLayer.landmark(at: scenePoint) {
            onSelectLandmark?(bookID)
        } else if let id = connectionLayer.connection(near: Iso.grid(scenePoint)) {
            onSelectConnection?(id)
        }
    }

    // MARK: Progress

    /// Something worth showing the player: a building completing, or a road being built.
    private enum Moment: Equatable {
        case celebrate(String)
        case road(String)
        case story(String)
    }

    /// Brings landmarks, fog and roads in line with the player's progress.
    func apply(_ newProgress: GameProgress) {
        progress = newProgress
        guard didConfigure else { return }
        let revealed = Set(WorldData.regions.map(\.id).filter { newProgress.isRegionRevealed($0) })
        let completed = Set(WorldData.landmarks.map(\.bookID).filter { newProgress.stage(of: $0) == .complete })

        // Existing installs: don't replay celebrations for books finished before this version.
        if UserDefaults.standard.array(forKey: StorageKeys.celebrated) == nil {
            UserDefaults.standard.set(Array(completed), forKey: StorageKeys.celebrated)
        }
        // Forget celebrations for books no longer complete, so finishing again celebrates again.
        let celebrated = Set(UserDefaults.standard.stringArray(forKey: StorageKeys.celebrated) ?? [])
        UserDefaults.standard.set(Array(celebrated.intersection(completed)), forKey: StorageKeys.celebrated)

        if appliedProgress {
            fogLayer.reveal(revealed, animated: true)
            landmarkLayer.apply(newProgress, animated: true)
        } else {
            appliedProgress = true
            fogLayer.configure(revealed: revealed)
            landmarkLayer.apply(newProgress, animated: false)
        }
        chapterObjectLayer.apply(newProgress, animated: false)
        queueStoryMoments(newProgress)
        for bookID in completed.subtracting(celebrated) { enqueue(.celebrate(bookID)) }
        // Characters live at finished landmarks; new arrivals wait for their celebration.
        characterLayer.sync(present: completed.intersection(celebrated))
        decorationLayer.setFogged(Set(WorldData.regions.map(\.id).filter { !revealed.contains($0) }), animated: true)
        syncRoads()
        if isOnScreen { playNextMoment() }
    }

    /// Shows roads already built; queues newly earned ones. Waits for terrain (to find water).
    private func syncRoads() {
        guard let progress, terrain != nil else { return }
        let active = Set(progress.activeConnections.map(\.id))
        if UserDefaults.standard.array(forKey: StorageKeys.builtConnections) == nil {
            UserDefaults.standard.set(Array(active), forKey: StorageKeys.builtConnections)
        }
        let stored = Set(UserDefaults.standard.stringArray(forKey: StorageKeys.builtConnections) ?? []).intersection(active)
        UserDefaults.standard.set(Array(stored), forKey: StorageKeys.builtConnections)
        connectionLayer.removeRoads(notIn: active)
        connectionLayer.show(stored, terrain: terrain)
        moments.removeAll { if case .road(let id) = $0 { return !active.contains(id) } else { return false } }
        for id in active.subtracting(stored).subtracting(connectionLayer.built) { enqueue(.road(id)) }
    }

    /// Story objects that are new or deeper than last seen get a moment (remembered across launches).
    private func queueStoryMoments(_ progress: GameProgress) {
        let current = Dictionary(uniqueKeysWithValues: ChapterLandmarks.visible.map { ($0.id, progress.depth(of: $0)) })
        guard var seen = UserDefaults.standard.dictionary(forKey: StorageKeys.storyObjectsSeen) as? [String: Int] else {
            UserDefaults.standard.set(current, forKey: StorageKeys.storyObjectsSeen)
            return
        }
        for (id, depth) in current where depth < (seen[id] ?? 0) { seen[id] = depth } // undone reads
        UserDefaults.standard.set(seen, forKey: StorageKeys.storyObjectsSeen)
        for entry in ChapterLandmarks.visible where (current[entry.id] ?? 0) > (seen[entry.id] ?? 0) {
            enqueue(.story(entry.id))
        }
    }

    private func enqueue(_ moment: Moment) {
        if !moments.contains(moment) { moments.append(moment) }
    }

    /// Call when the World tab becomes visible / hidden.
    func setOnScreen(_ visible: Bool) {
        isOnScreen = visible
        if visible { playNextMoment() }
    }

    private func playNextMoment() {
        guard isOnScreen, !moments.isEmpty, action(forKey: "moment") == nil else { return }
        switch moments.removeFirst() {
        case .celebrate(let bookID):
            guard let landmark = WorldData.landmark(bookID: bookID) else { return playNextMoment() }
            var celebrated = Set(UserDefaults.standard.stringArray(forKey: StorageKeys.celebrated) ?? [])
            celebrated.insert(bookID)
            UserDefaults.standard.set(Array(celebrated), forKey: StorageKeys.celebrated)
            flyTo(grid: landmark.center, zoom: min(cameraNode.xScale, 1.3))
            run(.sequence([.wait(forDuration: 0.75), .run { [weak self] in
                self?.landmarkLayer.celebrate(bookID)
                self?.landmarkDidComplete(bookID)
            }, .wait(forDuration: 1.6), .run { [weak self] in
                self?.playNextMoment()
            }]), withKey: "moment")

        case .story(let id):
            guard let entry = ChapterLandmarks.entry(id: id), let progress else { return playNextMoment() }
            var seen = UserDefaults.standard.dictionary(forKey: StorageKeys.storyObjectsSeen) as? [String: Int] ?? [:]
            seen[id] = progress.depth(of: entry)
            UserDefaults.standard.set(seen, forKey: StorageKeys.storyObjectsSeen)
            flyTo(grid: entry.center, zoom: min(cameraNode.xScale, 1.2))
            run(.sequence([.wait(forDuration: 0.7), .run { [weak self] in
                guard let self, let point = self.chapterObjectLayer.position(of: id) else { return }
                self.chapterObjectLayer.pop(id)
                self.landmarkLayer.puff(at: point, z: 5_500, big: false)
            }, .wait(forDuration: 1.2), .run { [weak self] in
                self?.playNextMoment()
            }]), withKey: "moment")

        case .road(let id):
            guard let frame = connectionLayer.frame(of: id) else { return playNextMoment() }
            let fitZoom = frame.length * Iso.tileWidth * 0.75 / max(size.width, 1)
            flyTo(grid: frame.mid, zoom: min(maxZoom, max(cameraNode.xScale, fitZoom)))
            run(.sequence([.wait(forDuration: 0.7), .run { [weak self] in
                guard let self else { return }
                let duration = self.connectionLayer.animateIn(id, terrain: self.terrain)
                var built = Set(UserDefaults.standard.stringArray(forKey: StorageKeys.builtConnections) ?? [])
                built.insert(id)
                UserDefaults.standard.set(Array(built), forKey: StorageKeys.builtConnections)
                self.run(.sequence([.wait(forDuration: duration + 0.4), .run { [weak self] in
                    self?.playNextMoment()
                }]), withKey: "moment")
            }]), withKey: "moment")
        }
    }

    private func landmarkDidComplete(_ bookID: String) {
        characterLayer.arrive(for: bookID)
    }

    /// Flies to the most recently read landmark (or the starting view).
    func recentre() {
        if let bookID = progress?.newestBookID, let landmark = WorldData.landmark(bookID: bookID) {
            flyTo(grid: landmark.center, zoom: 1.1)
        } else {
            let state = CameraState.default
            flyTo(CGPoint(x: state.x, y: state.y), zoom: state.scale)
        }
    }

    // MARK: Performance harness (DEBUG only)

    #if DEBUG
    private var perfFrames = 0
    private var perfStart: TimeInterval = 0
    private var perfWorst: TimeInterval = 0
    private var perfLast: TimeInterval = 0
    private var autopanStart: TimeInterval = 0

    /// `-autopan` sweeps the camera around the map with zoom changes and prints frame
    /// statistics every few seconds, so terrain streaming and culling can be measured.
    private func autopan(currentTime: TimeInterval) {
        guard ProcessInfo.processInfo.arguments.contains("-autopan") else { return }
        if autopanStart == 0 { autopanStart = currentTime; perfStart = currentTime; perfLast = currentTime }
        let t = currentTime - autopanStart
        let centre = Iso.scene(64, 48)
        cameraNode.position = CGPoint(x: centre.x + cos(t * 0.25) * 2600, y: centre.y + sin(t * 0.25) * 1100)
        cameraNode.setScale(1.6 + sin(t * 0.4) * 1.2)
        clampCamera()

        perfFrames += 1
        perfWorst = max(perfWorst, currentTime - perfLast)
        perfLast = currentTime
        if currentTime - perfStart >= 4 {
            let fps = Double(perfFrames) / (currentTime - perfStart)
            print(String(format: "PERF fps=%.1f worstFrame=%.1fms nodes=%d chunks=%d detail=%d decorations=%d",
                         fps, perfWorst * 1000, countNodes(self), chunkSprites.count, detailTextures.count, decorationLayer.itemCount))
            perfFrames = 0; perfWorst = 0; perfStart = currentTime
        }
    }

    private func countNodes(_ node: SKNode) -> Int {
        node.children.reduce(1) { $0 + countNodes($1) }
    }
    #endif
}
