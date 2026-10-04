/// Immutable witness dispatch preserves both original injection contracts.
internal enum NonlinearPhysicalSuppliers: Sendable {
    case spatial(any RigidEquationComputing, any ConstrainedMechanismSolving)
    case physical(any PhysicalRigidEquationComputing, any PhysicalConstrainedMechanismSolving)
    case prescribed(any PhysicalRigidEquationComputing, any PrescribedRootMechanismSolving)
    var usesPhysical: Bool { if case .spatial = self { return false }; return true }
    @inline(never)
    func assemble(_ input: PhysicalRigidDynamicsInput, admission: DynamicsAdmission, load: inout LoadWork,
                  work: inout NumericalWork) throws(DynamicsError) -> PhysicalRigidDynamicsSystem {
        switch self {
        case .spatial(let kernel, _):
            guard case .spatial(let source)=input.source else { throw .unsupportedDomain }
            return PhysicalRigidDynamicsSystem(spatial:try kernel.assemble(source,admission:admission,loadWork:&load,work:&work))
        case .physical(let kernel, _), .prescribed(let kernel, _): return try kernel.assemble(input,admission:admission,loadWork:&load,work:&work)
        }
    }
    @inline(never)
    func solve(_ context: NonlinearPhysicalSolveContext, drive: [Double], policy: MechanismSolvePolicy,
               a: inout NumericalWork, b: inout NumericalWork, c: inout NumericalWork, d: inout NumericalWork) throws(MechanismError) -> ConstrainedMotion {
        switch self {
        case .spatial(_, let solver):
            let system: RigidDynamicsSystem
            do throws(DynamicsError) { system=try context.system.spatialSystem() } catch { throw .dynamics(error) }
            return context.impulse ? try solver.reconcileVelocity(system,sample:context.sample,policy:policy,work:&a,dynamicsWork:&b,rankWork:&c,linearWork:&d)
                : try solver.acceleration(system,sample:context.sample,drive:drive,policy:policy,work:&a,dynamicsWork:&b,rankWork:&c,linearWork:&d)
        case .physical(_, let solver):
            let result=context.impulse ? try solver.reconcileVelocity(context.system,sample:context.sample,policy:policy,work:&a,dynamicsWork:&b,rankWork:&c,linearWork:&d)
                : try solver.acceleration(context.system,sample:context.sample,drive:drive,policy:policy,work:&a,dynamicsWork:&b,rankWork:&c,linearWork:&d)
            guard result.system === context.system else { throw .staleBinding }
            return result.motion
        case .prescribed(_, let solver):
            guard let root=context.prescribedRoot,root.system === context.system else { throw .staleBinding }
            let result=context.impulse ? try solver.reconcileVelocity(root,policy:policy,work:&a,dynamicsWork:&b,rankWork:&c,linearWork:&d)
                : try solver.acceleration(root,drive:drive,policy:policy,work:&a,dynamicsWork:&b,rankWork:&c,linearWork:&d)
            guard result.system === context.system else { throw .staleBinding }
            return result.motion
        }
    }
    @inline(never)
    func energy(_ system: PhysicalRigidDynamicsSystem, acceleration: [Double], work: inout NumericalWork) throws(DynamicsError) -> MechanicalEnergy {
        switch self {
        case .spatial(let kernel, _): return try kernel.energy(system.spatialSystem(),acceleration:acceleration,angularMomentumReference:.zero,requireComplete:false,work:&work)
        case .physical(let kernel, _), .prescribed(let kernel, _): return try kernel.energy(system,acceleration:acceleration,angularMomentumReference:.zero,requireComplete:false,work:&work)
        }
    }
}
