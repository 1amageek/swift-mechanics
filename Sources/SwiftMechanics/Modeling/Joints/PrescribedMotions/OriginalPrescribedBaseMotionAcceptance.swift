/// Builtin original mathematics is authority; injected supplier diagnostics cannot change the law.
public enum OriginalPrescribedBaseMotionAcceptance {
    @inline(never)
    public static func validated(_ supplied: PrescribedBaseMotionSample, program: PrescribedBaseMotionProgram,
                                 time: Double, policy: PrescribedMotionPolicy,
                                 work: inout NumericalWork) throws(PrescribedMotionError) -> PrescribedBaseMotionSample {
        let context = try prepare(program, time: time, policy: policy, work: &work)
        return try accept(supplied, context: context, policy: policy)
    }

    @inline(never)
    public static func sealedBaseMotion(_ program: PrescribedBaseMotionProgram, time: Double, policy: PrescribedMotionPolicy,
                                        sampler: any PrescribedBaseMotionSampling,
                                        work: inout NumericalWork) throws(PrescribedMotionError) -> PrescribedBaseMotionSample {
        let context = try prepare(program, time: time, policy: policy, work: &work)
        let supplied = try invoke(program, time: time, policy: policy, sampler: sampler,
            reservedStorage: context.reservedStorage, work: &work)
        return try accept(supplied, context: context, policy: policy)
    }

    @inline(never)
    private static func prepare(_ program: PrescribedBaseMotionProgram, time: Double, policy: PrescribedMotionPolicy,
                                work: inout NumericalWork) throws(PrescribedMotionError) -> OriginalBaseMotionContext {
        try PrescribedBaseMotionArithmetic.admit(program, policy: policy)
        let reserve: Int, operations: Int
        do throws(NumericalError) {
            reserve = try NumericalWork.sum(512, program.metadata.utf8.count / 8 + 1)
            operations = try NumericalWork.sum(program.metadata.utf8.count, 256)
        } catch { throw .numerical(error) }
        // Original computation and comparison allowance execute before opaque work is admitted.
        try PrescribedBaseMotionArithmetic.reserve(reserve, operations: operations, work: &work)
        let original = try AnalyticPrescribedBaseMotionSampler().sampleBase(program, time: time, policy: policy, work: &work)
        return OriginalBaseMotionContext(original: original, reservedStorage: reserve)
    }

    @inline(never)
    private static func invoke(_ program: PrescribedBaseMotionProgram, time: Double, policy: PrescribedMotionPolicy,
                               sampler: any PrescribedBaseMotionSampling, reservedStorage: Int,
                               work: inout NumericalWork) throws(PrescribedMotionError) -> PrescribedBaseMotionSample {
        try PrescribedBaseMotionArithmetic.check(policy)
        var local: NumericalWork
        do throws(NumericalError) {
            try work.chargeOperations(1)
            local = NumericalWork(budget: try work.remainingBudget(reservedStorage: reservedStorage))
            try local.chargeOperations(1)
        } catch { throw .numerical(error) }
        let seed = local
        var supplied: PrescribedBaseMotionSample?, failure: PrescribedMotionError?
        do throws(PrescribedMotionError) { supplied = try sampler.sampleBase(program, time: time, policy: policy, work: &local) }
        catch { failure = error }
        guard local.budget == seed.budget, local.operations >= seed.operations,
              local.iterations >= seed.iterations, local.peakScalarStorage >= seed.peakScalarStorage else {
            do throws(NumericalError) { try work.absorb(seed, reservedStorage: reservedStorage) }
            catch { throw .numerical(error) }
            throw .supplierLedgerReplaced
        }
        do throws(NumericalError) { try work.absorb(local, reservedStorage: reservedStorage) }
        catch { throw .numerical(error) }
        if let failure { throw failure }
        try PrescribedBaseMotionArithmetic.check(policy)
        guard let supplied else { throw .supplierWorkUnavailable }
        return supplied
    }

    @inline(never)
    private static func accept(_ supplied: PrescribedBaseMotionSample, context: OriginalBaseMotionContext,
                               policy: PrescribedMotionPolicy) throws(PrescribedMotionError) -> PrescribedBaseMotionSample {
        try PrescribedBaseMotionArithmetic.check(policy)
        let original = context.original
        guard supplied.metadata.utf8.count <= policy.maximumMetadataBytes,
              supplied.frame.key.utf8.count <= policy.maximumIdentifierBytes,
              supplied.worldFrame.key.utf8.count <= policy.maximumIdentifierBytes else { throw .capacityExceeded }
        guard supplied.metadata == original.metadata, supplied.layout == original.layout,
              supplied.frame == original.frame, supplied.worldFrame == original.worldFrame,
              supplied.time.bitPattern == original.time.bitPattern,
              numbers(supplied.q, original.q), numbers(supplied.v, original.v), numbers(supplied.a, original.a),
              numbers(supplied.coordinateRate, original.coordinateRate), motion(supplied.motion, original.motion) else { throw .staleSource }
        try PrescribedBaseMotionArithmetic.check(policy)
        return original
    }
    private static func numbers(_ left: [Double], _ right: [Double]) -> Bool {
        guard left.count == right.count else { return false }
        for i in right.indices { if left[i].bitPattern != right[i].bitPattern { return false } }
        return true
    }
    private static func vector(_ left: Vector3, _ right: Vector3) -> Bool {
        left.x.bitPattern == right.x.bitPattern && left.y.bitPattern == right.y.bitPattern && left.z.bitPattern == right.z.bitPattern
    }
    private static func motion(_ left: FrameMotion, _ right: FrameMotion) -> Bool {
        let a = left.pose.rotation, b = right.pose.rotation
        return vector(left.pose.translation, right.pose.translation) && a.w.bitPattern == b.w.bitPattern &&
            a.x.bitPattern == b.x.bitPattern && a.y.bitPattern == b.y.bitPattern && a.z.bitPattern == b.z.bitPattern &&
            vector(left.velocity.angular, right.velocity.angular) && vector(left.velocity.linear, right.velocity.linear) &&
            vector(left.acceleration.angular, right.acceleration.angular) && vector(left.acceleration.linear, right.acceleration.linear)
    }
}
