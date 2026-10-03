import MechanicsCore
import MechanicsNumerics

public struct EquilibriumLinearization: Sendable {
    public let operatingPoint: EquilibriumSolution
    public let reduction: EquilibriumReduction
    public let reducedMass: [Double]
    public let reducedStiffness: [Double]
    public let reducedDamping: [Double]
    public let stateMatrix: [Double]
    public let inputMatrix: [Double]
    public let outputMatrix: [Double]
    public let maximumDirectionalError: Double
    public let maximumInertialError: Double
    public let work: NumericalWork
    /// State [eta, etaDot], input dimensionless model parameter, output dimensions from reduction.
    public var stateCount: Int { 2*reduction.freeCoordinates }
}
