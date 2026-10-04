/// One root-frame law, separate from the articulated anchor inventory.
public struct PrescribedBaseMotionProgram: Sendable {
    public let law: AnalyticPrescribedMotion
    public let layout: BaseLayout
    public let metadata: String
    public let policy: PrescribedMotionPolicy
    public let initialPlanarAngle: Double?

    public init(law: AnalyticPrescribedMotion, layout: BaseLayout, policy: PrescribedMotionPolicy,
                work: inout NumericalWork) throws(PrescribedMotionError) {
        try PrescribedBaseMotionArithmetic.check(policy)
        guard layout != .fixed else { throw .unsupportedChart }
        guard law.frame.key.utf8.count <= policy.maximumIdentifierBytes,
              law.parentFrame.key.utf8.count <= policy.maximumIdentifierBytes else { throw .capacityExceeded }
        let bytes: Int
        do throws(NumericalError) {
            bytes = try NumericalWork.sum(800, try NumericalWork.product(3,
                try NumericalWork.sum(law.frame.key.utf8.count, law.parentFrame.key.utf8.count)))
        } catch { throw .numerical(error) }
        guard bytes <= policy.maximumMetadataBytes else { throw .capacityExceeded }
        let storage: Int, operations: Int
        do throws(NumericalError) {
            storage = try NumericalWork.sum(128, bytes / 8 + 1)
            operations = try NumericalWork.sum(bytes, 128)
        } catch { throw .numerical(error) }
        try PrescribedBaseMotionArithmetic.reserve(storage, operations: operations, work: &work)
        let angle: Double?
        if layout == .planarFloating {
            let pose = law.initialPose, axis = law.rotationAxis
            guard pose.translation.z == 0, law.translationRate.z == 0, law.translationAcceleration.z == 0,
                  pose.rotation.x == 0, pose.rotation.y == 0,
                  axis.x == 0, axis.y == 0, abs(axis.z) == 1 else { throw .nonPlanarMotion }
            do throws(CoreError) { angle = try pose.rotation.rotationVector().z }
            catch { throw .mathematical(error) }
        } else { angle = nil }
        var signature = layout == .planarFloating ? "analytic-base-v1:planar-principal-unwrapped" : "analytic-base-v1:spatial-body-angular"
        signature.reserveCapacity(bytes)
        func number(_ value: Double) { signature.append(":"); signature.append(String(value.bitPattern, radix: 16)) }
        func vector(_ value: Vector3) { number(value.x); number(value.y); number(value.z) }
        func identifier(_ id: EntityID) {
            signature.append(":"); signature.append(String(id.key.utf8.count)); signature.append(":")
            for byte in id.key.utf8 { signature.append(String(byte, radix: 16)); signature.append(".") }
        }
        identifier(law.frame); identifier(law.parentFrame); number(law.referenceTime)
        vector(law.initialPose.translation)
        let rotation = law.initialPose.rotation
        number(rotation.w); number(rotation.x); number(rotation.y); number(rotation.z)
        vector(law.translationRate); vector(law.translationAcceleration); vector(law.rotationAxis)
        number(law.angularRate); number(law.angularAcceleration); number(law.minimumTime); number(law.maximumTime)
        if let angle { number(angle) }
        guard signature.utf8.count <= bytes else { throw .capacityExceeded }
        try PrescribedBaseMotionArithmetic.check(policy)
        self.law = law; self.layout = layout; self.policy = policy
        metadata = signature; initialPlanarAngle = angle
    }
}
