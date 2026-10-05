public struct LinearRowMultiplier: Sendable {
    public let row: LinearRowOrigin
    public let normalized: Double
    public let physicalValue: Double
    /// Physical conjugate dimension is objectiveReference.dimension / rowReference.dimension.
    public let rowReference: SIReferenceQuantity<Double>
    public let objectiveReference: SIReferenceQuantity<Double>
    internal init(row: LinearRowOrigin, normalized: Double, physicalValue: Double,
                  rowReference: SIReferenceQuantity<Double>, objectiveReference: SIReferenceQuantity<Double>) {
        self.row = row; self.normalized = normalized; self.physicalValue = physicalValue
        self.rowReference = rowReference; self.objectiveReference = objectiveReference
    }
}
