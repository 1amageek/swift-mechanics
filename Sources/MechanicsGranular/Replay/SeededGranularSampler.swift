import MechanicsNumerics
import MechanicsRuntime
public struct SeededGranularSampler: GranularSampling, Sendable {
    public init() {}
    public func sample(count: Int, templates: [GranularDistributionTemplate], random: RuntimeRandomState, policy: GranularPolicy,
        numericalWork: inout NumericalWork, supplierWork: inout GranularSupplierWork) throws(GranularError) -> GranularDistributionResult {
        try GranularArithmetic.check(policy)
        guard count > 0, !templates.isEmpty else { throw .invalidInput }
        guard count <= policy.maximumParticles else { throw .capacity(resource:"particles",limit:policy.maximumParticles) }
        guard templates.count <= policy.maximumParticles else { throw .capacity(resource:"templates",limit:policy.maximumParticles) }
        try GranularArithmetic.storage(GranularArithmetic.addCount(GranularArithmetic.product(count,8),8),work:&numericalWork)
        var total: UInt64=0
        for t in templates {
            try GranularArithmetic.charge(16,policy:policy,work:&numericalWork)
            let (next,overflow)=total.addingReportingOverflow(t.weight)
            guard !overflow else { throw .arithmeticFailure }; total=next
        }
        // Rejection removes modulo bias; rejected RNG draws are retained and caller iteration/call bounded.
        let threshold=(0 &- total)%total
        var rng=random, output=[GranularSample](); output.reserveCapacity(count)
        for _ in 0..<count {
            var draw: UInt64
            repeat {
                try GranularArithmetic.charge(32,policy:policy,work:&numericalWork)
                do { try numericalWork.advanceIteration() } catch { throw .numerical(error) }
                try supplierWork.begin()
                do { draw=try rng.next() } catch { throw .runtime(error) }
            } while draw < threshold
            let value=draw%total
            var cumulative: UInt64=0, selected: Int?=nil
            for i in templates.indices {
                try GranularArithmetic.charge(16,policy:policy,work:&numericalWork)
                cumulative += templates[i].weight
                if value < cumulative { selected=i; break }
            }
            guard let selected else { throw .arithmeticFailure }
            let t=templates[selected]
            try GranularArithmetic.charge(32,policy:policy,work:&numericalWork)
            let mass=try GranularArithmetic.finite((4.0/3.0)*Double.pi*t.density*t.radius*t.radius*t.radius)
            guard mass > 0 else { throw .invalidInput }
            output.append(GranularSample(templateIndex:selected,template:t,mass:mass))
        }
        try GranularArithmetic.check(policy)
        return GranularDistributionResult(samples:output,random:rng)
    }
}
