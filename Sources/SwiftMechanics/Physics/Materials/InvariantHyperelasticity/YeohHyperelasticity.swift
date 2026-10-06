#if canImport(Darwin)
import Darwin
#elseif canImport(WASILibc)
import WASILibc
#elseif canImport(Glibc)
import Glibc
#else
#error("A scalar math platform is required.")
#endif

/// Calibrated isotropic Yeoh potential; see DESIGN.md for exact compressibility and fidelity.
public struct YeohHyperelasticity: Equatable, Sendable, HyperelasticResponding {
    public let c1: Double
    public let c2: Double
    public let c3: Double
    public let bulkModulus: Double
    public let domain: StrainDomain

    public init(c1: Double, c2: Double, c3: Double, bulkModulus: Double, domain: StrainDomain) throws(MaterialError) {
        guard c1.isFinite, c1 > 0, c2.isFinite, c2 >= 0, c3.isFinite, c3 >= 0, bulkModulus.isFinite, bulkModulus > 0 else { throw .invalidParameter(name: "YeohParameters") }
        self.c1=c1
        self.c2=c2
        self.c3=c3
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
        return try InvariantEnergyDerivatives(energy: x*(c1+x*(c2+x*c3))+bulkModulus*d*d/2,
            w1: c1+x*(2*c2+3*c3*x), wj: bulkModulus*d, w11: 2*c2+6*c3*x, wjj: bulkModulus)
    }
}
