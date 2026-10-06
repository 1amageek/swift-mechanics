@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
public protocol StructuralMechanismCreating: Sendable {
    func equation(_ system: StructuralMechanicalSystem, identity: String, policy: MechanismSolvePolicy,
                  admission: DynamicsAdmission, maximumIdentityBytes: Int) throws(StructuralSystemFailure) -> AffineMechanismEquation
    func loadedEquation(_ system: StructuralMechanicalSystem, identity: String, policy: MechanismSolvePolicy,
                        admission: DynamicsAdmission, execution: any StationaryLoadExecuting,
                        maximumIdentityBytes: Int) throws(StructuralSystemFailure) -> StationaryAffineMechanismEquation
}
