/// Bounded immutable authority retained by reference across snapshot phases.
internal final class GeometricTrajectoryBinding: Sendable {
    let anchor:PrescribedTrajectoryProgram?
    let root:PrescribedTrajectoryRootBinding?
    init(anchor:PrescribedTrajectoryProgram?,root:PrescribedTrajectoryRootBinding?) { self.anchor=anchor;self.root=root }
}
