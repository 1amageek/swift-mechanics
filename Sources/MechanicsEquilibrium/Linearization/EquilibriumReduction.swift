import MechanicsCore
public struct EquilibriumReduction: Sendable {
    public let freeCoordinates: Int
    /// Row-major n by freeCoordinates, physical q=N*eta with dimensionless eta.
    public let basis: [Double]
    /// Physical generalized damping; row-major n by n, symmetric linear law; passivity is not asserted.
    public let damping: [Double]
    public let outputRows: Int
    public let outputMap: [Double]
    public let outputDimensions: [PhysicalDimension]
    public init(freeCoordinates: Int, basis: [Double], damping: [Double], outputRows: Int, outputMap: [Double], outputDimensions: [PhysicalDimension]) {
        self.freeCoordinates=freeCoordinates; self.basis=basis; self.damping=damping; self.outputRows=outputRows; self.outputMap=outputMap; self.outputDimensions=outputDimensions
    }
}
