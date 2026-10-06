import SwiftMechanics

internal struct FailingFrameComposer: FrameMotionComposing {
    private enum Failure:Error { case selected }
    let returnsStationary:Bool
    init(returnsStationary:Bool=false) { self.returnsStationary=returnsStationary }
    func composed(parent:FrameMotion,relative:FrameMotion) throws -> FrameMotion {
        if returnsStationary { return .stationary(pose:.identity) }
        throw Failure.selected
    }
    func inverted(_ frame:FrameMotion) throws -> FrameMotion { throw Failure.selected }
}
