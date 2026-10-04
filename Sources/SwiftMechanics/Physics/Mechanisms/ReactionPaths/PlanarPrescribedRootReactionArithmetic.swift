internal enum PlanarPrescribedRootReactionArithmetic {
    static func tree<T>(_ body: () throws(ReactionPathError) -> T) throws(PlanarPrescribedRootReactionError) -> T {
        do { return try body() } catch {
            switch error {
            case .supplierLedgerReplaced: throw .supplierLedgerReplaced
            case .invalidSupplierEvidence: throw .invalidSupplierEvidence
            case .loadLedgerMerge(let cause): throw .loadLedgerMerge(cause)
            case .cancelled: throw .cancelled
            default: throw .tree(error)
            }
        }
    }
    static func numeric<T>(_ body: () throws(NumericalError) -> T) throws(PlanarPrescribedRootReactionError) -> T {
        do { return try body() } catch { throw .numerical(error) }
    }
    static func charge(_ amount: Int, _ work: inout NumericalWork) throws(PlanarPrescribedRootReactionError) {
        try numeric { () throws(NumericalError) in try work.chargeOperations(amount) }
    }
    static func finite(_ value: Double) throws(PlanarPrescribedRootReactionError) -> Double {
        guard value.isFinite else { throw .invalidInput };return value
    }
    static func check(_ policy: PlanarPrescribedRootReactionPolicy) throws(PlanarPrescribedRootReactionError) {
        guard !Task.isCancelled,!policy.geometry.isCancelled(),!policy.mechanism.isCancelled(),
              !policy.mechanism.constraints.evaluation.isCancelled(),!policy.tree.isCancelled() else { throw .cancelled }
    }
    static func layout(_ a: ConstraintCoordinateLayout, _ b: ConstraintCoordinateLayout) -> Bool {
        a.coordinateIDs == b.coordinateIDs && a.dimensions == b.dimensions && a.scales == b.scales &&
        a.timeScale == b.timeScale && a.revision == b.revision
    }
    static func equal(_ a: VelocityConstraintSample, _ b: VelocityConstraintSample) -> Bool {
        layout(a.layout,b.layout) && a.rowIDs == b.rowIDs && a.rows == b.rows && a.drift == b.drift &&
        a.accelerationBias == b.accelerationBias && a.isIntegrable == b.isIntegrable
    }
    static func residual(_ a: Double, _ b: Double, index: Int, policy: TreeReactionPolicy) throws(PlanarPrescribedRootReactionError) -> Double {
        let scale=policy.generalizedForceScales[index],value=try finite((a-b)/scale)
        let magnitude=try finite(max(abs(a),abs(b))/scale)
        let accepted: Bool
        do throws(CoreError) { accepted=try policy.generalizedTolerance.contains(error:value,scale:magnitude) }
        catch { throw .core(error) }
        guard accepted else { throw .tree(.originalGeneralizedResidual(index:index,scaledValue:value)) }
        return abs(value)
    }
    static func projection(_ value: PlanarReactionWrench, _ column: SpatialMotion) throws(PlanarPrescribedRootReactionError) -> Double {
        try finite(finite(value.forceX*column.linear.x)+finite(value.forceY*column.linear.y)+finite(value.momentZ*column.angular.z))
    }
}
