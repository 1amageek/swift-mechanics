public struct WheeledAssemblyTopology: Equatable, Sendable {
    public let chassis, rearCarrier, rearWheel, frontCarrier, frontKnuckle, frontWheel: EntityID
    public let rearSuspension, frontSuspension, rearSpin, steering, frontSpin: EntityID
    public init(chassis: EntityID, rearCarrier: EntityID, rearWheel: EntityID, frontCarrier: EntityID,
                frontKnuckle: EntityID, frontWheel: EntityID, rearSuspension: EntityID,
                frontSuspension: EntityID, rearSpin: EntityID, steering: EntityID, frontSpin: EntityID) throws(WheeledAssemblyFailure) {
        let bodies = [chassis,rearCarrier,rearWheel,frontCarrier,frontKnuckle,frontWheel]
        let joints = [rearSuspension,frontSuspension,rearSpin,steering,frontSpin]
        guard bodies.allSatisfy({ $0.kind == .body }), joints.allSatisfy({ $0.kind == .joint }),
              Set(bodies).count == 6, Set(joints).count == 5 else { throw .refusal(.invalidInput) }
        self.chassis=chassis; self.rearCarrier=rearCarrier; self.rearWheel=rearWheel
        self.frontCarrier=frontCarrier; self.frontKnuckle=frontKnuckle; self.frontWheel=frontWheel
        self.rearSuspension=rearSuspension; self.frontSuspension=frontSuspension
        self.rearSpin=rearSpin; self.steering=steering; self.frontSpin=frontSpin
    }
}
