/// Immutable metric and acceptance owner. Reusing a state requires this exact owner.
public final class NonlinearStabilityPolicy: Sendable {
    public let equilibrium: EquilibriumPolicy
    public let evidence: EquilibriumLinearizationPolicy
    public let spectrum: ComplexSpectrumPolicy
    public let dynamics: DynamicsAdmission
    public let loadBudget: LoadBudget
    public let parameterScale: Double
    public let arcTolerance: Double
    public let spectralTolerance: Double
    public let zeroStiffnessTolerance: Double
    public let loadProjectionTolerance: Double
    public let minimumMassPivot: Double
    public let maximumArcStep: Double
    public let maximumCorrection: Double
    public let maximumAcceptedPoints: Int
    public let maximumCriticalIterations: Int
    public let criticalWidth: Double
    public let isCancelled: @Sendable () -> Bool
    public init(equilibrium: EquilibriumPolicy, evidence: EquilibriumLinearizationPolicy,
                spectrum: ComplexSpectrumPolicy, dynamics: DynamicsAdmission, loadBudget: LoadBudget,
                parameterScale: Double, arcTolerance: Double, spectralTolerance: Double,
                zeroStiffnessTolerance: Double, loadProjectionTolerance: Double, minimumMassPivot: Double,
                maximumArcStep: Double, maximumCorrection: Double, maximumAcceptedPoints: Int,
                maximumCriticalIterations: Int, criticalWidth: Double,
                isCancelled: @escaping @Sendable () -> Bool = { false }) throws(NonlinearStabilityFailure.Cause) {
        for x in [parameterScale,arcTolerance,spectralTolerance,zeroStiffnessTolerance,loadProjectionTolerance,
                  minimumMassPivot,maximumArcStep,maximumCorrection,criticalWidth] {
            guard x.isFinite,x>0 else { throw .invalidInput }
        }
        guard maximumAcceptedPoints>0,maximumCriticalIterations>0,
              equilibrium.physicalForceTolerances.count==evidence.derivativeAbsoluteTolerances.count,
              evidence.inertialAbsoluteTolerances.count==equilibrium.physicalForceTolerances.count else { throw .invalidInput }
        self.equilibrium=equilibrium;self.evidence=evidence;self.spectrum=spectrum;self.dynamics=dynamics;self.loadBudget=loadBudget
        self.parameterScale=parameterScale;self.arcTolerance=arcTolerance;self.spectralTolerance=spectralTolerance
        self.zeroStiffnessTolerance=zeroStiffnessTolerance;self.loadProjectionTolerance=loadProjectionTolerance
        self.minimumMassPivot=minimumMassPivot;self.maximumArcStep=maximumArcStep;self.maximumCorrection=maximumCorrection
        self.maximumAcceptedPoints=maximumAcceptedPoints;self.maximumCriticalIterations=maximumCriticalIterations
        self.criticalWidth=criticalWidth;self.isCancelled=isCancelled
    }
}
