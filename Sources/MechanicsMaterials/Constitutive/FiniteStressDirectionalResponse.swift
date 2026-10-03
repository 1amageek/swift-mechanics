import MechanicsCore

/// Analytic derivatives per unit supplied deformation-gradient direction.
public struct FiniteStressDirectionalResponse: Sendable {
    public let secondPiolaDirection: SymmetricTensor
    public let firstPiolaDirection: Matrix3
    public let cauchyDirection: Matrix3
}
