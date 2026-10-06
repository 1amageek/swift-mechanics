/// Isotropic hard impulse friction is explicitly selected, independently of continuous elastic history.
public struct FrictionalImpulsePolicy: Sendable {
    public let hybrid: HybridPolicy
    public let joints: JointEvaluationPolicy
    public let admission: DynamicsAdmission
    public let mass: DynamicsSolvePolicy
    public let tangentTolerance: LinearTolerance<Double>
    public let coefficient: Double
    public let massScaleKg: Double
    public let velocityScale: Double
    public let impulseTolerance: NumericalTolerance
    public let maximumBracketIterations: Int
    public let maximumBisectionIterations: Int
    public let isCancelled: @Sendable () -> Bool
    public init(hybrid: HybridPolicy, joints: JointEvaluationPolicy, admission: DynamicsAdmission,
                mass: DynamicsSolvePolicy, tangentTolerance: LinearTolerance<Double>, coefficient: Double,
                massScaleKg: Double, velocityScale: Double, impulseTolerance: NumericalTolerance,
                maximumBracketIterations: Int, maximumBisectionIterations: Int,
                isCancelled: @escaping @Sendable () -> Bool = { false }) throws(FrictionalImpulseFailure) {
        guard coefficient.isFinite, coefficient >= 0, massScaleKg.isFinite, massScaleKg > 0,
              velocityScale.isFinite, velocityScale > 0, (massScaleKg*velocityScale).isFinite,
              massScaleKg*velocityScale > 0, maximumBracketIterations > 0, maximumBisectionIterations > 0 else {
            throw FrictionalImpulseFailure(.invalidInput)
        }
        self.hybrid=hybrid; self.joints=joints; self.admission=admission; self.mass=mass
        self.tangentTolerance=tangentTolerance; self.coefficient=coefficient; self.massScaleKg=massScaleKg
        self.velocityScale=velocityScale; self.impulseTolerance=impulseTolerance
        self.maximumBracketIterations=maximumBracketIterations; self.maximumBisectionIterations=maximumBisectionIterations
        self.isCancelled=isCancelled
    }
}
