import SwiftMechanics
#if canImport(Darwin)
import Darwin
#elseif canImport(WASILibc)
import WASILibc
#elseif canImport(Glibc)
import Glibc
#else
#error("The verification profile must provide system scalar mathematics.")
#endif

extension FoundationVerification {
    @inline(never)
    static func verifyDerivatives() throws {
        let context = try DerivativeProbeContext()
        var workspace = MechanicalDerivativeWorkspace()
        var work = NumericalWork(budget: try NumericalBudget(scalarStorage: 100000, arithmeticOperations: 1000000, iterations: 100))
        var loads = LoadWork(budget: try LoadBudget(maximumWork: 100, maximumScalars: 0)), calls = try DerivativeSupplierWork(maximumCalls: 100)
        let service: any MechanicalDifferentiating = ExactMechanicalDifferentiator()
        let result = try service.forwardDirection(context.input, direction: context.direction, jointPolicy: context.jointPolicy,
            admission: context.admission, solvePolicy: context.solve, policy: context.policy, workspace: &workspace, loadWork: &loads, supplierWork: &calls, work: &work)
        try require(abs(result.mechanics.system.massMatrix[0] - 6) < 1e-9 && abs(result.mechanics.massMatrix[0]) < 1e-9)
        try require(abs(result.mechanics.totalForce[0] - 20 * sin(0.4)) < 1e-9)
        try require(abs(result.acceleration[0] - 20 * sin(0.4) / 6) < 1e-9 && result.originalResidual <= result.originalThreshold)
        let jacobian = try service.forwardJacobian(context.input, variable: .drive, jointPolicy: context.jointPolicy,
            admission: context.admission, solvePolicy: context.solve, policy: context.policy, workspace: &workspace, loadWork: &loads, supplierWork: &calls, work: &work)
        try require(jacobian.coordinateCount == 1 && abs(jacobian.values[0] - 1.0 / 6) < 1e-9 && calls.calls > 0 && work.operations > 0)
        let scalar: any ScalarDifferentiating = ExactScalarDifferentiator()
        var unavailable = false
        do throws(DerivativeError) { _ = try scalar.evaluate(.squareRoot, left: DirectionalScalar(value: 0, direction: 1), right: nil, work: &work) }
        catch { guard case .derivativeUnavailable = error else { throw error }; unavailable = true }
        try require(unavailable)
    }
}
