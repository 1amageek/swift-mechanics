
internal final class HardImpactRowBodies: Sendable {
    let geometry: HardImpactRowGeometry
    let first: BodyKinematics
    let second: BodyKinematics
    init(geometry: HardImpactRowGeometry, first: BodyKinematics, second: BodyKinematics) { self.geometry=geometry; self.first=first; self.second=second }
}
