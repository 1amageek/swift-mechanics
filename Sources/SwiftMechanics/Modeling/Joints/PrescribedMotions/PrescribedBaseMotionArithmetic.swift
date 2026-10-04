internal enum PrescribedBaseMotionArithmetic {
    static func check(_ policy: PrescribedMotionPolicy) throws(PrescribedMotionError) {
        guard !Task.isCancelled, !policy.isCancelled() else { throw .cancelled }
    }
    static func reserve(_ storage: Int, operations: Int, work: inout NumericalWork) throws(PrescribedMotionError) {
        do throws(NumericalError) { try work.requireStorage(storage); try work.chargeOperations(operations) }
        catch { throw .numerical(error) }
    }
    static func admit(_ program: PrescribedBaseMotionProgram, policy: PrescribedMotionPolicy) throws(PrescribedMotionError) {
        try check(policy)
        guard program.metadata.utf8.count <= policy.maximumMetadataBytes,
              program.law.frame.key.utf8.count <= policy.maximumIdentifierBytes,
              program.law.parentFrame.key.utf8.count <= policy.maximumIdentifierBytes else { throw .capacityExceeded }
    }
}
