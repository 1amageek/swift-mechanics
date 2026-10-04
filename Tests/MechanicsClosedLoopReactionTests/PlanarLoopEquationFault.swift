import SwiftMechanics

/// Faults occur after real equation/gravity work, never instead of exercising that producer.
internal struct PlanarLoopEquationFault: PhysicalRigidEquationComputing {
    enum Mode: Sendable { case unchanged, resetNumerical, resetLoads, changedInput, changedInertia, replaceCancellation }
    let mode: Mode
    let fails: Bool
    let foreign: PhysicalRigidDynamicsSystem?
    let onAssembly: @Sendable () -> Void
    init(mode:Mode,fails:Bool=false,foreign:PhysicalRigidDynamicsSystem?=nil,onAssembly:@escaping @Sendable ()->Void={}) {
        self.mode=mode;self.fails=fails;self.foreign=foreign;self.onAssembly=onAssembly
    }
    func assemble(_ input:PhysicalRigidDynamicsInput,admission:DynamicsAdmission,loadWork:inout LoadWork,work:inout NumericalWork) throws(DynamicsError) -> PhysicalRigidDynamicsSystem {
        let source:PhysicalRigidDynamicsInput
        if mode == .changedInput || mode == .changedInertia {
            guard case .planar(let original)=input.source else { throw .dimensionMismatch }
            let inertias:[PlanarRigidBodyInertia]
            if mode == .changedInertia {
                guard let foreign,case .planar(let replacement)=foreign.input.source else { throw .invalidInput }
                inertias=replacement.inertias
            } else { inertias=original.inertias }
            source=try PhysicalRigidDynamicsInput(planar:PlanarRigidDynamicsInput(snapshot:input.snapshot,velocity:input.velocity,inertias:inertias,
                gravity:input.gravity,bodyWrenches:mode == .changedInput ? [] : input.bodyWrenches,generalizedForces:input.generalizedForces))
        } else { source=input }
        let system=try RigidEquationKernel().assemble(source,admission:admission,loadWork:&loadWork,work:&work)
        if mode == .resetNumerical { work=NumericalWork(budget:work.budget) }
        if mode == .resetLoads { loadWork=LoadWork(budget:loadWork.budget) }
        if mode == .replaceCancellation {
            do throws(LoadError) {
                var replacement=LoadWork(budget:try LoadBudget(maximumWork:loadWork.budget.maximumWork,maximumScalars:loadWork.budget.maximumScalars,isCancelled:{false}))
                try replacement.charge(loadWork.consumed);try replacement.reserve(scalars:loadWork.peakScalars)
                loadWork=replacement
            } catch { throw .loads(error) }
        }
        onAssembly()
        if fails { throw .invalidInput }
        return system
    }
    func originalInertialForce(_ system:PhysicalRigidDynamicsSystem,acceleration:[Double],includeBias:Bool,into output:inout [Double],work:inout NumericalWork) throws(DynamicsError) {
        try RigidEquationKernel().originalInertialForce(system,acceleration:acceleration,includeBias:includeBias,into:&output,work:&work)
    }
    func inertialWrench(_ system:PhysicalRigidDynamicsSystem,body:EntityID,acceleration:[Double],referencePointWorld:Vector3,work:inout NumericalWork) throws(DynamicsError) -> BodyWrenchEvidence {
        try RigidEquationKernel().inertialWrench(system,body:body,acceleration:acceleration,referencePointWorld:referencePointWorld,work:&work)
    }
    func energy(_ system:PhysicalRigidDynamicsSystem,acceleration:[Double],angularMomentumReference:Vector3,requireComplete:Bool,work:inout NumericalWork) throws(DynamicsError) -> MechanicalEnergy {
        try RigidEquationKernel().energy(system,acceleration:acceleration,angularMomentumReference:angularMomentumReference,requireComplete:requireComplete,work:&work)
    }
}
