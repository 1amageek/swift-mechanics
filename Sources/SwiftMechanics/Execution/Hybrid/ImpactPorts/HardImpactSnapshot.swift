
internal final class HardImpactSnapshot: Sendable {
    let request: HardImpactRequest
    let snapshot: KinematicSnapshot
    init(request: HardImpactRequest, snapshot: KinematicSnapshot) { self.request=request; self.snapshot=snapshot }
}
