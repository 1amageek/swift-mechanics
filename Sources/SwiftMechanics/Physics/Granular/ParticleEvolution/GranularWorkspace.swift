public struct GranularWorkspace: Sendable {
    internal var forces: [Vector3] = []
    internal var torques: [Vector3] = []
    internal var motions: [GranularMotion] = []
    internal var contacts: [GranularContactState] = []
    internal var observations: [GranularContactObservation] = []
    internal var neighbors: [GranularNeighbor] = []
    internal var reactions: [GranularBoundaryReaction] = []
    public init() {}
    internal var retainedSlots: Int {
        get throws(GranularError) {
            var slots=try GranularArithmetic.product(forces.capacity,3)
            slots=try GranularArithmetic.addCount(slots,GranularArithmetic.product(torques.capacity,3))
            slots=try GranularArithmetic.addCount(slots,GranularArithmetic.product(motions.capacity,9))
            slots=try GranularArithmetic.addCount(slots,GranularArithmetic.product(contacts.capacity,100))
            slots=try GranularArithmetic.addCount(slots,GranularArithmetic.product(observations.capacity,140))
            slots=try GranularArithmetic.addCount(slots,GranularArithmetic.product(neighbors.capacity,2))
            return try GranularArithmetic.addCount(slots,GranularArithmetic.product(reactions.capacity,7))
        }
    }
}
