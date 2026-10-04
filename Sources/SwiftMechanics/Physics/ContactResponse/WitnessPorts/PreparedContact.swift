public struct PreparedContact: Sendable {
    public let binding: WitnessContact
    public let firstBody: BodyKinematics
    public let secondBody: BodyKinematics
    public let firstOffset: Vector3
    public let secondOffset: Vector3
    public let normalRow: [Double]
    public let normalDrift: Double
    public let relativeDrift: Vector3
    public let stiffness: Double
    internal init(binding: WitnessContact, firstBody: BodyKinematics, secondBody: BodyKinematics,
                  firstOffset: Vector3, secondOffset: Vector3, normalRow: [Double], normalDrift: Double, relativeDrift: Vector3, stiffness: Double) {
        self.binding=binding; self.firstBody=firstBody; self.secondBody=secondBody; self.firstOffset=firstOffset; self.secondOffset=secondOffset
        self.normalRow=normalRow; self.normalDrift=normalDrift; self.relativeDrift=relativeDrift; self.stiffness=stiffness
    }
}
