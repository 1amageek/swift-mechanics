public struct OrthotropicElasticEvaluator: OrthotropicElasticEvaluating {
    public init() {}
    public func evaluate(law: OrthotropicElasticLaw, strain: SymmetricTensor, domain: StrainDomain) throws(MaterialError) -> OrthotropicElasticResponse {
        try domain.validate(strain: strain)
        let stress = try tangent(law: law, direction: strain)
        // Cholesky squares preserve nonnegative stored energy even with coupled normal stiffness.
        let a = try finite(law.l11*strain.xx + law.l21*strain.yy + law.l31*strain.zz)
        let b = try finite(law.l22*strain.yy + law.l32*strain.zz)
        let c = try finite(law.l33*strain.zz)
        let energy = try finite(0.5*law.normalScale*a*a + 0.5*law.normalScale*b*b + 0.5*law.normalScale*c*c
            + 2*law.g12*strain.xy*strain.xy + 2*law.g23*strain.yz*strain.yz + 2*law.g13*strain.xz*strain.xz)
        return OrthotropicElasticResponse(stress: stress, energyDensity: energy)
    }
    public func tangent(law: OrthotropicElasticLaw, direction e: SymmetricTensor) throws(MaterialError) -> SymmetricTensor {
        try SymmetricTensor(xx: finite(law.c11*e.xx + law.c12*e.yy + law.c13*e.zz),
            yy: finite(law.c12*e.xx + law.c22*e.yy + law.c23*e.zz),
            zz: finite(law.c13*e.xx + law.c23*e.yy + law.c33*e.zz),
            xy: finite(2*law.g12*e.xy), yz: finite(2*law.g23*e.yz), xz: finite(2*law.g13*e.xz))
    }
    private func finite(_ value: Double) throws(MaterialError) -> Double {
        guard value.isFinite else { throw .nonFiniteResult(operation: "OrthotropicElasticity") }
        return value
    }
}
