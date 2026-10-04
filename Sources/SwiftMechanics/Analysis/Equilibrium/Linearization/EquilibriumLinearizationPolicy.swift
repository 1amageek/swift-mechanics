public struct EquilibriumLinearizationPolicy: Sendable {
    public let limits: EquilibriumLimits
    public let capability: LinearCapability
    public let tolerance: LinearTolerance<Double>
    public let displacementProbe: Double
    public let parameterProbe: Double
    public let derivativeAbsoluteTolerances: [Double]
    public let derivativeRelativeTolerance: Double
    public let constraintTolerance: Double
    public let inertialAbsoluteTolerances: [Double]
    public let isCancelled: @Sendable () -> Bool
    public init(limits: EquilibriumLimits, capability: LinearCapability, tolerance: LinearTolerance<Double>, displacementProbe: Double, parameterProbe: Double,
                derivativeAbsoluteTolerances: [Double], derivativeRelativeTolerance: Double, constraintTolerance: Double,
                inertialAbsoluteTolerances: [Double], isCancelled: @escaping @Sendable () -> Bool = { false }) throws(EquilibriumError) {
        guard displacementProbe.isFinite,displacementProbe>0,parameterProbe.isFinite,parameterProbe>0,derivativeRelativeTolerance.isFinite,derivativeRelativeTolerance>=0,
            constraintTolerance.isFinite,constraintTolerance>=0,derivativeAbsoluteTolerances.count<=limits.coordinates,inertialAbsoluteTolerances.count<=limits.coordinates else { throw .invalidInput }
        for t in derivativeAbsoluteTolerances { guard t.isFinite,t>=0 else { throw .invalidInput } }
        for t in inertialAbsoluteTolerances { guard t.isFinite,t>=0 else { throw .invalidInput } }
        self.limits=limits;self.capability=capability;self.tolerance=tolerance;self.displacementProbe=displacementProbe;self.parameterProbe=parameterProbe
        self.derivativeAbsoluteTolerances=derivativeAbsoluteTolerances;self.derivativeRelativeTolerance=derivativeRelativeTolerance;self.constraintTolerance=constraintTolerance
        self.inertialAbsoluteTolerances=inertialAbsoluteTolerances;self.isCancelled=isCancelled
    }
}
