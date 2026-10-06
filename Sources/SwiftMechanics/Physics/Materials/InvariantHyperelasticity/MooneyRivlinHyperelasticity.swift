#if canImport(Darwin)
import Darwin
#elseif canImport(WASILibc)
import WASILibc
#elseif canImport(Glibc)
import Glibc
#else
#error("A scalar math platform is required.")
#endif

/// Calibrated isotropic MooneyRivlin potential; see DESIGN.md for exact compressibility and fidelity.
public struct MooneyRivlinHyperelasticity: Equatable, Sendable, HyperelasticResponding {
    public let c1: Double
    public let c2: Double
    public let bulkModulus: Double
    public let domain: StrainDomain

    public init(c1: Double, c2: Double, bulkModulus: Double, domain: StrainDomain) throws(MaterialError) {
        guard c1.isFinite, c1 >= 0, c2.isFinite, c2 >= 0, c1+c2 > 0, bulkModulus.isFinite, bulkModulus > 0 else { throw .invalidParameter(name: "MooneyRivlinParameters") }
        self.c1=c1
        self.c2=c2
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
        let d=j-1
        return try InvariantEnergyDerivatives(energy: c1*x+c2*y+bulkModulus*d*d/2,
            w1: c1, w2: c2, wj: bulkModulus*d, wjj: bulkModulus)
    }
}
