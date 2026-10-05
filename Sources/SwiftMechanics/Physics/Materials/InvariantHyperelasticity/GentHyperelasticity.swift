#if canImport(Darwin)
import Darwin
#elseif canImport(WASILibc)
import WASILibc
#elseif canImport(Glibc)
import Glibc
#else
#error("A scalar math platform is required.")
#endif

/// Calibrated isotropic Gent potential; see DESIGN.md for exact compressibility and fidelity.
public struct GentHyperelasticity: Equatable, Sendable, HyperelasticResponding {
    public let shearModulus: Double
    public let lockingInvariant: Double
    public let bulkModulus: Double
    public let domain: StrainDomain

    public init(shearModulus: Double, lockingInvariant: Double, bulkModulus: Double, domain: StrainDomain) throws(MaterialError) {
        guard shearModulus.isFinite, shearModulus > 0, lockingInvariant.isFinite, lockingInvariant > 0, bulkModulus.isFinite, bulkModulus > 0 else { throw .invalidParameter(name: "GentParameters") }
        self.shearModulus=shearModulus
        self.lockingInvariant=lockingInvariant
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
        guard x < lockingInvariant else { throw .outsideDomain(measure: "GentLockingInvariant", value: x, limit: lockingInvariant) }
        let ratio=x/lockingInvariant, denominator=1-ratio, d=j-1
        return try InvariantEnergyDerivatives(energy: -shearModulus*(lockingInvariant/2)*log1p(-ratio)+bulkModulus*d*d/2,
            w1: (shearModulus/2)/denominator, wj: bulkModulus*d,
            w11: (shearModulus/2)/lockingInvariant/denominator/denominator, wjj: bulkModulus)
    }
}
