import MechanicsNumerics
public struct ModalResult: Sendable {
    public let binding: StructuralBinding
    /// Ascending eigenvalues in s^-2; columns of modes are physical mass-normalized vectors.
    public let eigenvalues: [Double]
    public let modes: [Double]
    public let classifications: [ModeClassification]
    public let maximumOriginalResidual: Double
    public let maximumMassOrthogonalityError: Double
    public let work: NumericalWork
}
