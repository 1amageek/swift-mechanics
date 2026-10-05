internal struct GeometryFrameJet: Sendable {
    let rotation: GeometryMatrixJet
    let translation: GeometryVectorJet
    let velocity: GeometryMotionJet
    let acceleration: GeometryMotionJet
    init(rotation: GeometryMatrixJet = .identity, translation: GeometryVectorJet = .zero,
         velocity: GeometryMotionJet = .zero, acceleration: GeometryMotionJet = .zero) {
        self.rotation = rotation; self.translation = translation; self.velocity = velocity; self.acceleration = acceleration
    }
    static let identity = GeometryFrameJet()
    static func fixed(_ pose: RigidTransform, translation: Vector3, bodyRotation: Vector3,
                      work: inout NumericalWork) throws(GeometryParameterError) -> GeometryFrameJet {
        let r = try GeometryParameterArithmetic.core { () throws(CoreError) in try pose.rotation.matrix() }
        let h = try GeometryParameterArithmetic.hat(bodyRotation, &work)
        return GeometryFrameJet(rotation: GeometryMatrixJet(r, try GeometryParameterArithmetic.core { () throws(CoreError) in try r.multiplied(by: h) }),
                                translation: GeometryVectorJet(pose.translation, translation))
    }
    static func inverseFixed(_ f: GeometryFrameJet, work: inout NumericalWork) throws(GeometryParameterError) -> GeometryFrameJet {
        let r = GeometryMatrixJet(f.rotation.value.transposed(), f.rotation.direction.transposed())
        return GeometryFrameJet(rotation: r, translation: try GeometryParameterArithmetic.scale(GeometryParameterArithmetic.apply(r, f.translation, &work), -1, &work))
    }
    static func compose(_ p: GeometryFrameJet, _ r: GeometryFrameJet,
                        work: inout NumericalWork) throws(GeometryParameterError) -> GeometryFrameJet {
        let offset = try GeometryParameterArithmetic.apply(p.rotation, r.translation, &work)
        let rw = try GeometryParameterArithmetic.apply(p.rotation, r.velocity.angular, &work)
        let rv = try GeometryParameterArithmetic.apply(p.rotation, r.velocity.linear, &work)
        let rotation = try GeometryParameterArithmetic.multiply(p.rotation, r.rotation, &work)
        let translation = try GeometryParameterArithmetic.add(p.translation, offset, &work)
        let omega = try GeometryParameterArithmetic.add(p.velocity.angular, rw, &work)
        let velocity = try GeometryParameterArithmetic.add(GeometryParameterArithmetic.add(p.velocity.linear,
            GeometryParameterArithmetic.cross(p.velocity.angular, offset, &work), &work), rv, &work)
        let alpha = try GeometryParameterArithmetic.add(GeometryParameterArithmetic.add(p.acceleration.angular,
            GeometryParameterArithmetic.apply(p.rotation, r.acceleration.angular, &work), &work), GeometryParameterArithmetic.cross(p.velocity.angular, rw, &work), &work)
        var acceleration = try GeometryParameterArithmetic.add(p.acceleration.linear, GeometryParameterArithmetic.cross(p.acceleration.angular, offset, &work), &work)
        acceleration = try GeometryParameterArithmetic.add(acceleration, GeometryParameterArithmetic.cross(p.velocity.angular,
            GeometryParameterArithmetic.cross(p.velocity.angular, offset, &work), &work), &work)
        acceleration = try GeometryParameterArithmetic.add(acceleration, GeometryParameterArithmetic.scale(GeometryParameterArithmetic.cross(p.velocity.angular, rv, &work), 2, &work), &work)
        acceleration = try GeometryParameterArithmetic.add(acceleration, GeometryParameterArithmetic.apply(p.rotation, r.acceleration.linear, &work), &work)
        return GeometryFrameJet(rotation: rotation, translation: translation, velocity: GeometryMotionJet(omega, velocity), acceleration: GeometryMotionJet(alpha, acceleration))
    }
}
