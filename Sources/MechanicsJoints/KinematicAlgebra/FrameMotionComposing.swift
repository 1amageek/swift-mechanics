public protocol FrameMotionComposing: Sendable {
    func composed(parent: FrameMotion, relative: FrameMotion) throws -> FrameMotion
    func inverted(_ frame: FrameMotion) throws -> FrameMotion
}
