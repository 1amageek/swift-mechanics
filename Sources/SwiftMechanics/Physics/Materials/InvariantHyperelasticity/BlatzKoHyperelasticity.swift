#if canImport(Darwin)
import Darwin
#elseif canImport(WASILibc)
import WASILibc
#elseif canImport(Glibc)
import Glibc
#else
#error("A scalar math platform is required.")
#endif

/// Calibrated isotropic BlatzKo potential; see DESIGN.md for exact compressibility and fidelity.
public struct BlatzKoHyperelasticity: Equatable, Sendable, HyperelasticResponding {
    public let shearModulus: Double
    public let domain: StrainDomain

    public init(shearModulus: Double, domain: StrainDomain) throws(MaterialError) {
        guard shearModulus.isFinite, shearModulus > 0 else { throw .invalidParameter(name: "BlatzKoParameters") }
        self.shearModulus=shearModulus
        self.domain=domain
    }

    public func evaluate(deformationGradient: Matrix3) throws(MaterialError) -> FiniteStressResponse {
        try InvariantHyperelasticKernel(f: deformationGradient, domain: domain).evaluate(potential)
    }

    public func tangent(deformationGradient: Matrix3, direction: Matrix3) throws(MaterialError) -> FiniteStressDirectionalResponse {
        try InvariantHyperelasticKernel(f: deformationGradient, domain: domain).tangent(h: direction, potential: potential)
    }

    private func potential(_ x: Double, _ y: Double, _ j: Double) throws(MaterialError) -> InvariantEnergyDerivatives {
        let z=log(j), a=exp(-2*z/3), g=exp(-5*z/3)
        let energy=(shearModulus/2)*(a*y+3*ihExpRemainder(-2*z/3)+2*ihExpRemainder(z))
        return try InvariantEnergyDerivatives(energy: energy, w2: (shearModulus/2)*a,
            wj: shearModulus*(1-(y+3)*g/3), w2j: -shearModulus*g/3,
            wjj: 5*shearModulus*(y+3)*exp(-8*z/3)/9)
    }
}
