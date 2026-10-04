
public enum EquilibriumError: Error, Sendable {
    case invalidInput, capacityExceeded, staleBinding, outsideDomain, branchExceeded, cancelled, nonFiniteResult
    case unsupportedDomain, reactionAmbiguity(nullity: Int), rankChanged, invalidReduction, operatingPointMismatch
    case originalBalance(coordinate: Int, residual: Double)
    case originalConstraint(row: Int, residual: Double)
    case derivativeMismatch(coordinate: Int, error: Double)
    case force(StaticForceError)
    case numerical(NumericalError)
    case nonlinear(NonlinearFailure<Double>)
    case constraint(ConstraintError)
    case constraintFailure(ConstraintError, failedSupplierWorkUnavailable: Bool)
    case dynamics(DynamicsError)
    case compilation
    /// A failed foreign solver does not publish its work; continuation must stop.
    case linear(NumericalError, failedSupplierWorkUnavailable: Bool)
}

internal func equilibriumNumerics<T>(_ body: () throws(NumericalError) -> T) throws(EquilibriumError) -> T {
    do { return try body() } catch { throw .numerical(error) }
}
internal func boundedIdentity(_ value: String, limit: Int) throws(EquilibriumError) {
    guard !value.isEmpty else { throw .invalidInput }
    var count=0
    for _ in value.utf8 { guard count < limit else { throw .capacityExceeded }; count += 1 }
}

internal func equilibriumForce<T>(_ body: () throws(StaticForceError) -> T) throws(EquilibriumError) -> T {
    do { return try body() } catch { throw .force(error) }
}
