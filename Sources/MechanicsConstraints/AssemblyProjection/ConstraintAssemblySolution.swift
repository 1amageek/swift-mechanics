import MechanicsNumerics
import MechanicsNonlinear

public struct ConstraintAssemblySolution: Sendable {
    public let position: [Double]
    public let originalResidual: Double
    public let stationarityResidual: Double
    public let correctionNorm: Double
    public let geometricObjective: Double
    /// No dynamic reaction or physical work is inferred by geometric assembly.
    public let physicalIntroducedWork: Double? = nil
    public let rank: ConstraintRankEvidence
    public let nonlinearDiagnostics: NonlinearDiagnostics<Double>
    public let responseWork: NumericalWork
    public init(position: [Double], originalResidual: Double, stationarityResidual: Double, correctionNorm: Double, geometricObjective: Double,
                  rank: ConstraintRankEvidence, nonlinearDiagnostics: NonlinearDiagnostics<Double>, responseWork: NumericalWork) {
        self.position=position; self.originalResidual=originalResidual; self.stationarityResidual=stationarityResidual
        self.correctionNorm=correctionNorm; self.geometricObjective=geometricObjective; self.rank=rank
        self.nonlinearDiagnostics=nonlinearDiagnostics; self.responseWork=responseWork
    }
}
