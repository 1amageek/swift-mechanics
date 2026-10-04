internal enum PlanarReactionArithmetic {
    static let zero=PlanarReactionWrench(forceX:0,forceY:0,momentZ:0)
    static func core<T>(_ body:() throws(CoreError)->T) throws(ReactionPathError)->T {
        do { return try body() } catch { throw .core(error) }
    }
    static func numeric<T>(_ body:() throws(NumericalError)->T) throws(ReactionPathError)->T {
        do { return try body() } catch { throw .numerical(error) }
    }
    static func finite(_ value:Double) throws(ReactionPathError)->Double {
        guard value.isFinite else { throw .invalidInput };return value
    }
    static func check(_ policy:TreeReactionPolicy) throws(ReactionPathError) {
        guard !Task.isCancelled,!policy.isCancelled() else { throw .cancelled }
    }
    static func charge(_ amount:Int,_ work:inout NumericalWork) throws(ReactionPathError) {
        try numeric { () throws(NumericalError) in try work.chargeOperations(amount) }
    }
    static func reduced(_ value:SpatialWrench) throws(ReactionPathError)->PlanarReactionWrench {
        guard value.force.z == 0,value.torque.x == 0,value.torque.y == 0 else { throw .dynamics(.nonplanarInput) }
        return PlanarReactionWrench(forceX:try finite(value.force.x),forceY:try finite(value.force.y),momentZ:try finite(value.torque.z))
    }
    static func add(_ a:PlanarReactionWrench,_ b:PlanarReactionWrench) throws(ReactionPathError)->PlanarReactionWrench {
        PlanarReactionWrench(forceX:try finite(a.forceX+b.forceX),forceY:try finite(a.forceY+b.forceY),momentZ:try finite(a.momentZ+b.momentZ))
    }
    static func subtract(_ a:PlanarReactionWrench,_ b:PlanarReactionWrench) throws(ReactionPathError)->PlanarReactionWrench {
        PlanarReactionWrench(forceX:try finite(a.forceX-b.forceX),forceY:try finite(a.forceY-b.forceY),momentZ:try finite(a.momentZ-b.momentZ))
    }
    static func negated(_ value:PlanarReactionWrench)->PlanarReactionWrench {
        PlanarReactionWrench(forceX:-value.forceX,forceY:-value.forceY,momentZ:-value.momentZ)
    }
    static func shifted(_ value:PlanarReactionWrench,from:Vector3,to:Vector3) throws(ReactionPathError)->PlanarReactionWrench {
        let dx=try finite(from.x-to.x),dy=try finite(from.y-to.y)
        let cross=try finite(finite(dx*value.forceY)-finite(dy*value.forceX))
        return PlanarReactionWrench(forceX:value.forceX,forceY:value.forceY,momentZ:try finite(value.momentZ+cross))
    }
    static func converted(_ value:PlanarReactionWrench,referenceWorld:Vector3,pose:RigidTransform) throws(ReactionPathError)->PlanarReactionWrench {
        let relocated=try Self.shifted(value,from:.zero,to:referenceWorld)
        let force=try core { () throws(CoreError) in try pose.rotation.conjugated().rotating(Vector3(relocated.forceX,relocated.forceY,0)) }
        return PlanarReactionWrench(forceX:force.x,forceY:force.y,momentZ:relocated.momentZ)
    }
    static func agrees(_ a:PlanarReactionWrench,_ b:PlanarReactionWrench,policy:TreeReactionPolicy) throws(ReactionPathError)->Bool {
        try core { () throws(CoreError)->Bool in
            let x=try policy.forceTolerance.contains(error:a.forceX-b.forceX,scale:max(abs(a.forceX),abs(b.forceX)))
            let y=try policy.forceTolerance.contains(error:a.forceY-b.forceY,scale:max(abs(a.forceY),abs(b.forceY)))
            let z=try policy.torqueTolerance.contains(error:a.momentZ-b.momentZ,scale:max(abs(a.momentZ),abs(b.momentZ)))
            return x && y && z
        }
    }
    static func ledger(_ before:NumericalWork,_ after:inout NumericalWork) throws(ReactionPathError) {
        guard before.budget == after.budget,after.operations >= before.operations,after.iterations >= before.iterations,
              after.peakScalarStorage >= before.peakScalarStorage else { after=before;throw .supplierLedgerReplaced }
    }
    static func merge(_ before:LoadWork,supplier:LoadWork,into output:inout LoadWork) throws(ReactionPathError) {
        guard before.budget.maximumWork == supplier.budget.maximumWork,before.budget.maximumScalars == supplier.budget.maximumScalars,
              supplier.consumed >= before.consumed,supplier.peakScalars >= before.peakScalars else { throw .supplierLedgerReplaced }
        // Preserve the caller's original cancellation closure and known admission prefix.
        do { try output.charge(supplier.consumed-before.consumed);try output.reserve(scalars:supplier.peakScalars) }
        catch { throw .loadLedgerMerge(error) }
    }
}
