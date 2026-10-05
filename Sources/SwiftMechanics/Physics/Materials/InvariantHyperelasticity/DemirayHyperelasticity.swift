#if canImport(Darwin)
import Darwin
#elseif canImport(WASILibc)
import WASILibc
#elseif canImport(Glibc)
import Glibc
#else
#error("A scalar math platform is required.")
#endif

/// Calibrated isotropic Demiray potential; see DESIGN.md for exact compressibility and fidelity.
public struct DemirayHyperelasticity: Equatable, Sendable, HyperelasticResponding {
    public let shearModulus: Double
    public let stiffening: Double
    public let bulkModulus: Double
    public let domain: StrainDomain

    public init(shearModulus: Double, stiffening: Double, bulkModulus: Double, domain: StrainDomain) throws(MaterialError) {
        guard shearModulus.isFinite, shearModulus > 0, stiffening.isFinite, stiffening > 0, bulkModulus.isFinite, bulkModulus > 0 else { throw .invalidParameter(name: "DemirayParameters") }
        self.shearModulus=shearModulus
        self.stiffening=stiffening
        self.bulkModulus=bulkModulus
        self.domain=domain
    }

    public func evaluate(deformationGradient: Matrix3) throws(MaterialError) -> FiniteStressResponse {
        try InvariantHyperelasticKernel(f: deformationGradient, domain: domain).evaluate(potential)
    }

    public func tangent(deformationGradient: Matrix3, direction: Matrix3) throws(MaterialError) -> FiniteStressDirectionalResponse {
        try InvariantHyperelasticKernel(f: deformationGradient, domain: domain).tangent(h: direction, potential: potential)
    }

    private func potential(_ x: Double, _ y: Double, _ j: Double) throws(MaterialError) -> InvariantEnergyDerivatives {
        let argument=stiffening*x, d=j-1
        let first=(shearModulus/2)*exp(argument)
        return try InvariantEnergyDerivatives(energy: (shearModulus/2)/stiffening*expm1(argument)+bulkModulus*d*d/2,
            w1: first, wj: bulkModulus*d, w11: stiffening*first, wjj: bulkModulus)
    }
}
