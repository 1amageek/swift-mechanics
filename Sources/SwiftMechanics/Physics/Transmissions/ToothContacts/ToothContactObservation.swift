public struct ToothContactObservation: Sendable {
    public let pair: ToothContactPair
    public let witness: CollisionWitness
    public let relativePointVelocity: Vector3
    public let slipVelocity: Vector3
    public let response: ContactResponse
    public let forceOnA: Vector3
    public let forceOnB: Vector3
    public let torqueAtFirstBodyOrigin: Vector3
    public let torqueAtSecondBodyOrigin: Vector3
}
