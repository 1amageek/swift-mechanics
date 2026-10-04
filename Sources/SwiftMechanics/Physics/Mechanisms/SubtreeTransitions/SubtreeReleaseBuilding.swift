public protocol SubtreeReleaseBuilding: Sendable {
    func release(model: CompiledMechanicalModel, state: CompiledKinematicState, joint: EntityID,
                 connector: EntityID, parentAnchor: EntityID, childAnchor: EntityID, policy: SubtreeReleasePolicy,
                 admission: DynamicsAdmission, work: inout NumericalWork, dynamicsWork: inout NumericalWork) throws(TopologyReleaseFailure) -> SubtreeRelease
}
