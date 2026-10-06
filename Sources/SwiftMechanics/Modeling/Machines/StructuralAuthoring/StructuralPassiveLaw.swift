public struct StructuralPassiveLaw: Sendable {
    public let id: EntityID
    public let termID: UInt64
    public let joint: EntityID
    public let law: PolynomialSpringDamper
    internal init(id: EntityID, termID: UInt64, joint: EntityID, law: PolynomialSpringDamper) {
        self.id = id; self.termID = termID; self.joint = joint; self.law = law
    }
}
