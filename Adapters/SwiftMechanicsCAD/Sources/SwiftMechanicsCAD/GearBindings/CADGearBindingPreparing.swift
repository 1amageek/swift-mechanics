import SwiftMechanics

public protocol CADGearBindingPreparing: Sendable {
    func bind(_ request: CADGearPairRequest, geometry: CADGeometryAdmission,
              model: CompiledMechanicalModel, state: CompiledKinematicState,
              layout: ConstraintCoordinateLayout, policy: CADGearBindingPolicy,
              transmissionPolicy: TransmissionPolicy, work: inout CADAdapterWork,
              transmissionWork: inout NumericalWork) throws(CADGearBindingError) -> CADGearPairBinding
}
