import MechanicsModel
import MechanicsFlexible
public struct PressureBody: Sendable {
    public let body: ModelReference
    public let mesh: ValidatedTetrahedralMesh
    public let state: NodalState
    public let field: NodalPressureField?
    public init(body: ModelReference, mesh: ValidatedTetrahedralMesh, state: NodalState, field: NodalPressureField?) {
        self.body=body; self.mesh=mesh; self.state=state; self.field=field
    }
}
