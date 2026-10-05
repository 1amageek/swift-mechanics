public enum ParticleFlowError: Error, Equatable, Sendable {
    case invalidInput
    case invalidPolicy
    case duplicateIdentity(UInt64)
    case identityMismatch
    case nonFiniteArithmetic
    case insufficientSeparation(first: UInt64, second: UInt64)
    case tensileDomain(particle: UInt64, density: Double)
    case densityDomain(particle: UInt64, relativeDeviation: Double)
    case machDomain(particle: UInt64, mach: Double)
    case timeStepDomain(stage: Double, ratio: Double)
    case residualRejected(equation: String, value: Double)
    case unsupportedFreeSurface
    case unsupportedDynamicBoundary
    case core(CoreError)
    case numerical(NumericalError)
}
