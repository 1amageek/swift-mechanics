import MechanicsCore

internal final class HardImpactPointColumns: Sendable {
    let normal: Vector3
    let firstOffset: Vector3
    let secondOffset: Vector3
    let first: ArraySlice<SpatialMotion>
    let second: ArraySlice<SpatialMotion>
    init(normal: Vector3, firstOffset: Vector3, secondOffset: Vector3, first: ArraySlice<SpatialMotion>, second: ArraySlice<SpatialMotion>) { self.normal=normal; self.firstOffset=firstOffset; self.secondOffset=secondOffset; self.first=first; self.second=second }
}
