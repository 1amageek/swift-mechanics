#if canImport(Darwin)
import Darwin
#elseif canImport(WASILibc)
import WASILibc
#elseif canImport(Glibc)
import Glibc
#else
#error("A scalar math platform is required.")
#endif

/// Calibrated isotropic ArrudaBoyce potential; see DESIGN.md for exact compressibility and fidelity.
public struct ArrudaBoyceHyperelasticity: Equatable, Sendable, HyperelasticResponding {
    public let chainModulus: Double
    public let chainSegments: Double
    public let bulkModulus: Double
    public let domain: StrainDomain

    public init(chainModulus: Double, chainSegments: Double, bulkModulus: Double, domain: StrainDomain) throws(MaterialError) {
        guard chainModulus.isFinite, chainModulus > 0, chainSegments.isFinite, chainSegments > 1, bulkModulus.isFinite, bulkModulus > 0 else { throw .invalidParameter(name: "ArrudaBoyceParameters") }
        self.chainModulus=chainModulus
        self.chainSegments=chainSegments
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
        // Five-term inverse-Langevin expansion; no exact inverse-Langevin or small-strain renormalization.
        let s=x+3, inv=1/chainSegments
        guard s/3 < chainSegments else { throw .outsideDomain(measure: "ArrudaBoyceChainStretchSquared", value: s/3, limit: chainSegments) }
        let a2=inv/20, a3=11*inv*inv/1050, a4=19*inv*inv*inv/7000, a5=519*inv*inv*inv*inv/673750
        // Factored polynomial differences retain tiny shear work.
        let energy=x*(0.5+a2*(s+3)+a3*(s*s+3*s+9)+a4*(s*s*s+3*s*s+9*s+27)
            + a5*(s*s*s*s+3*s*s*s+9*s*s+27*s+81))
        let first=0.5+2*a2*s+3*a3*s*s+4*a4*s*s*s+5*a5*s*s*s*s
        let second=2*a2+6*a3*s+12*a4*s*s+20*a5*s*s*s, d=j-1
        return try InvariantEnergyDerivatives(energy: chainModulus*energy+bulkModulus*d*d/2,
            w1: chainModulus*first, wj: bulkModulus*d, w11: chainModulus*second, wjj: bulkModulus)
    }
}
