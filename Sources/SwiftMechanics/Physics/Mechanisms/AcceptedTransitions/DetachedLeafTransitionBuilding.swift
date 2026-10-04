
public protocol DetachedLeafTransitionBuilding: Sendable {
    func detach(model:CompiledMechanicalModel,state:CompiledKinematicState,joint:EntityID,connector:EntityID,
                parentAnchor:EntityID,childAnchor:EntityID,policy:DetachedLeafPolicy,admission:DynamicsAdmission,
                work:inout NumericalWork,dynamicsWork:inout NumericalWork) throws(MechanismError) -> DetachedLeafTransition
}
