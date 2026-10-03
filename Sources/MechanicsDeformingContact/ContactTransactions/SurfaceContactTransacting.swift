import MechanicsNumerics
import MechanicsContactLaws
public protocol SurfaceContactTransacting: Sendable {
    func initialState(_ snapshot: DeformingSurfaceSnapshot, bindings: [SurfaceContactBinding], policy: DeformingContactPolicy,
                      work: inout NumericalWork, lawWork: inout ContactWork) throws(DeformingContactError) -> SurfaceContactState
    func trial(_ state: SurfaceContactState, snapshot: DeformingSurfaceSnapshot, bindings: [SurfaceContactBinding], timeStep: Double,
               policy: DeformingContactPolicy, lawPolicy: ContactAcceptancePolicy, work: inout NumericalWork,
               lawWork: inout ContactWork) throws(DeformingContactError) -> SurfaceContactStep
    func accept(_ step: SurfaceContactStep, from state: SurfaceContactState) throws(DeformingContactError) -> SurfaceContactState
    func reject(_ step: SurfaceContactStep, from state: SurfaceContactState) throws(DeformingContactError) -> SurfaceContactState
}
