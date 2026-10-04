internal final class ConstrainedImpactMode: Sendable {
    let workspace: ConstrainedImpactWorkspace
    let before: Double
    let inverseMass: Double
    init(workspace: ConstrainedImpactWorkspace, before: Double, inverseMass: Double) {
        self.workspace = workspace; self.before = before; self.inverseMass = inverseMass
    }
}
