import Testing

/// The suites that render many pictures through the one shared `IslandRenderCache`. They run one at
/// a time: in parallel, one filling the cache with hundreds of megabytes of ground and Places while
/// another renders its own pictures made `ImageRenderer` hand back blank images (out of memory),
/// which failed pixel tests at random.
@Suite(.serialized)
struct ImageRenderingTests {}
