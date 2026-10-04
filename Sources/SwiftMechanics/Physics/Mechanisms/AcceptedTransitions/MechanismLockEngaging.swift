
@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
public protocol MechanismLockEngaging: Sendable {
    func engage(_ session:any RuntimeSessionOperating, expected:RuntimeAcceptedState, model:CompiledMechanicalModel,
                system:RigidDynamicsSystem,sample:VelocityConstraintSample,policy:MechanismSolvePolicy,
                equation:AffineMechanismEquation,continuation:IntegrationContinuationProvider,
                work:inout NumericalWork,dynamicsWork:inout NumericalWork,rankWork:inout NumericalWork,
                linearWork:inout NumericalWork) throws(MechanismError) -> MechanismEngagement
}
