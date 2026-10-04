import SwiftMechanics

internal struct SignEquivalentFrameComposer:FrameMotionComposing {
    func composed(parent:FrameMotion,relative:FrameMotion) throws -> FrameMotion {
        let original=try FrameMotionComposer().composed(parent:parent,relative:relative)
        let rotation=original.pose.rotation
        let equivalent=try UnitQuaternion(unitW:-rotation.w,x:-rotation.x,y:-rotation.y,z:-rotation.z)
        return FrameMotion(pose:try RigidTransform(rotation:equivalent,translation:original.pose.translation),
            velocity:original.velocity,acceleration:original.acceleration)
    }
    func inverted(_ frame:FrameMotion) throws -> FrameMotion {
        try FrameMotionComposer().inverted(frame)
    }
}
