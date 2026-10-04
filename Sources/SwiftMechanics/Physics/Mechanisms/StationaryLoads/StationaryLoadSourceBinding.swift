public protocol StationaryLoadSourceBinding: Sendable {
    func validate(model:CompiledMechanicalModel,layout:ConstraintCoordinateLayout) throws(StationaryLoadError)
    func physicalSignature(model:CompiledMechanicalModel,policy:MechanismSolvePolicy,admission:DynamicsAdmission,drive:[Double],maximumBytes:Int) throws(StationaryLoadError) -> [UInt8]
}
