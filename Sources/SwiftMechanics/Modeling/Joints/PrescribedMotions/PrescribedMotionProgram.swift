/// Bounded canonical analytic law authority; it has no compiled-model or Runtime dependency.
public struct PrescribedMotionProgram: Sendable {
    public let motions:[AnalyticPrescribedMotion]
    public let metadata:String
    public let policy:PrescribedMotionPolicy
    public init(motions:[AnalyticPrescribedMotion],policy:PrescribedMotionPolicy,work:inout NumericalWork) throws(PrescribedMotionError) {
        guard !motions.isEmpty,motions.count <= policy.maximumSamples else { throw .capacityExceeded }
        if policy.isCancelled() { throw .cancelled }
        do throws(NumericalError) {
            try work.requireStorage(try NumericalWork.product(64,motions.count))
            try work.chargeOperations(try NumericalWork.product(motions.count,motions.count))
        } catch { throw .numerical(error) }
        var count=24
        for (i,m) in motions.enumerated() {
                guard m.frame.key.utf8.count <= policy.maximumIdentifierBytes,m.parentFrame.key.utf8.count <= policy.maximumIdentifierBytes else { throw .capacityExceeded }
                guard !motions[..<i].contains(where:{$0.frame == m.frame}) else { throw .invalidFrame }
                do throws(NumericalError) { count=try NumericalWork.sum(count,try NumericalWork.sum(17*30,try NumericalWork.product(3,try NumericalWork.sum(m.frame.key.utf8.count,m.parentFrame.key.utf8.count)))) } catch { throw .numerical(error) }
        }
        guard count <= policy.maximumMetadataBytes else { throw .capacityExceeded }
        do throws(NumericalError) {
            try work.requireStorage(try NumericalWork.sum(try NumericalWork.product(64,motions.count),count/8+1))
            try work.chargeOperations(count)
        } catch { throw .numerical(error) }
        let ordered=motions.sorted { $0.frame.key < $1.frame.key }
        var signature="analytic-anchor-v1";signature.reserveCapacity(count)
        func number(_ value:Double) { signature.append(":");signature.append(String(value.bitPattern,radix:16)) }
        func vector(_ v:Vector3) { number(v.x);number(v.y);number(v.z) }
        func identifier(_ id:EntityID) { signature.append(":");signature.append(String(id.key.utf8.count));signature.append(":");for b in id.key.utf8 { signature.append(String(b,radix:16));signature.append(".") } }
        for m in ordered {
            identifier(m.frame);identifier(m.parentFrame);number(m.referenceTime);vector(m.initialPose.translation)
            for x in [m.initialPose.rotation.w,m.initialPose.rotation.x,m.initialPose.rotation.y,m.initialPose.rotation.z] { number(x) }
            vector(m.translationRate);vector(m.translationAcceleration);vector(m.rotationAxis)
            for x in [m.angularRate,m.angularAcceleration,m.minimumTime,m.maximumTime] { number(x) }
        }
        guard signature.utf8.count <= count else { throw .capacityExceeded }
        self.motions=ordered;metadata=signature;self.policy=policy
    }
}
