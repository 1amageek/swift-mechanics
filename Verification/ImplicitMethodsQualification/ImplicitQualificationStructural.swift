import SwiftMechanics

@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
public struct ImplicitQualificationStructural: StructuralImplicitEquations, Sendable {
    public let descriptor: ODEDescriptor
    public let residualDimensions: [PhysicalDimension] = [.force]
    public let implicitDomain: ImplicitEquationDomain
    public let massDomain: StructuralMassDomain
    public let physics: ImplicitQualificationPhysics
    public let fault: ImplicitQualificationFault
    public init(model: CompiledMechanicalModel, physics: ImplicitQualificationPhysics,
                fault: ImplicitQualificationFault = .none, domain: ImplicitEquationDomain = .smoothEuclidean,
                massDomain: StructuralMassDomain = .constantMass) throws(RuntimeFailure) {
        descriptor = try ODEDescriptor(identity: "implicit-original-structural-balance", chart: "prismatic-SI-displacement",
            model: model.stamp, dimensions: [.length], maximumIdentityBytes: 256, maximumCoordinates: 1)
        self.physics = physics; self.fault = fault; implicitDomain = domain; self.massDomain = massDomain
    }
    public func residual(time: Double, displacement: [Double], velocity: [Double], acceleration: [Double],
                         into output: inout [Double], work: inout NumericalWork) throws(ImplicitMethodCause) {
        try admit(time, displacement, velocity, acceleration, output, &work)
        if fault == .resetLedger { work = NumericalWork(budget: work.budget) }
        if fault == .unavailableFailure { throw .runtime(RuntimeFailure(.invalidState, message: "Declared opaque structural supplier failure.", failedSupplierWorkUnavailable: true)) }
        let force: ScalarLoadResponse
        do throws(RuntimeFailure) { force = try physics.loadResponse(q: displacement[0], v: velocity[0]) }
        catch { throw .runtime(error) }
        output[0] = physics.mass*acceleration[0]-force.conservative-force.dissipative-physics.constantLoad
    }
    public func originalResidual(time: Double, displacement: [Double], velocity: [Double], acceleration: [Double],
                                 into output: inout [Double], work: inout NumericalWork) throws(ImplicitMethodCause) {
        try admit(time, displacement, velocity, acceleration, output, &work)
        // Recompute the original declared force balance without reusing any ScalarLoadResponse or solver cache.
        output[0] = physics.originalBalance(q: displacement[0], v: velocity[0], a: acceleration[0])
            + (fault == .originalBalanceMismatch ? 0.01 : 0)
    }
    public func tangent(time: Double, displacement: [Double], velocity: [Double], acceleration: [Double],
                        displacementCoefficient: Double, velocityCoefficient: Double, accelerationCoefficient: Double,
                        into rowMajorOutput: inout [Double], work: inout NumericalWork) throws(ImplicitMethodCause) {
        try admit(time, displacement, velocity, acceleration, rowMajorOutput, &work)
        let derivative = physics.stiffness+3*physics.cubicStiffness*displacement[0]*displacement[0]
        rowMajorOutput[0] = displacementCoefficient*(fault == .wrongTangent ? 0 : derivative)
            + velocityCoefficient*physics.damping+accelerationCoefficient*physics.mass
    }
    private func admit(_ time: Double, _ q: [Double], _ v: [Double], _ a: [Double], _ output: [Double],
                       _ work: inout NumericalWork) throws(ImplicitMethodCause) {
        do throws(NumericalError) { try work.chargeOperations(24) }
        catch { throw .numerical(error) }
        guard time.isFinite && q.count == 1 && v.count == 1 && a.count == 1 && output.count == 1 else { throw .invalidEvaluation }
    }
}
