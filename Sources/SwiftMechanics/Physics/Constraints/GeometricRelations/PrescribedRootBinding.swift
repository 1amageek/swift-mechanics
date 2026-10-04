/// Actual compiled root authority, independent of the prescribed-anchor inventory.
public struct PrescribedRootBinding: PrescribedRootBindingProviding {
    public let program: PrescribedBaseMotionProgram
    public let knownCoordinates: [Int]
    public let dynamicCoordinates: [Int]
    public let rowIDs: [UInt64]
    internal init(model: CompiledMechanicalModel, program: PrescribedBaseMotionProgram, rowIDs: [UInt64],
                  work: inout NumericalWork) throws(GeometricConstraintError) {
        let tree = model.tree, k = tree.rootBase.velocityCount, n = tree.layout.velocityCount
        guard k > 0, program.layout == tree.rootBase, model.descriptor.rootAuthority == .prescribedMotion,
              let root = tree.bodies.first(where: { $0.id == model.descriptor.root }),
              program.law.frame == root.frame, program.law.parentFrame == tree.worldFrame,
              rowIDs.count == k else { throw .staleSource }
        try GeometricArithmetic.charge(try GeometricArithmetic.numeric { () throws(NumericalError) -> Int in
            try NumericalWork.sum(128, try NumericalWork.product(n, n))
        }, &work)
        for i in rowIDs.indices { guard !rowIDs[..<i].contains(rowIDs[i]) else { throw .invalidInput } }
        self.program = program; self.rowIDs = rowIDs
        knownCoordinates = Array(0..<k); dynamicCoordinates = Array(k..<n)
        try validate(model.descriptor.initialState, work: &work)
    }
    public func sample(time: Double, work: inout NumericalWork) throws(GeometricConstraintError) -> PrescribedBaseMotionSample {
        do throws(PrescribedMotionError) {
            return try AnalyticPrescribedBaseMotionSampler().sampleBase(program, time: time, policy: program.policy, work: &work)
        } catch { throw .motion(error) }
    }
    public func validate(_ state: KinematicState, work: inout NumericalWork) throws(GeometricConstraintError) {
        let original = try sample(time: state.time, work: &work)
        guard state.q.count >= original.q.count, state.v.count >= original.v.count,
              state.acceleration.count == state.v.count else { throw .invalidShape }
        try GeometricArithmetic.charge(64, &work)
        for i in original.q.indices { guard state.q[i].bitPattern == original.q[i].bitPattern else { throw .staleSource } }
        for i in original.v.indices {
            guard state.v[i].bitPattern == original.v[i].bitPattern,
                  state.acceleration[i].bitPattern == original.a[i].bitPattern else { throw .staleSource }
        }
    }
}
