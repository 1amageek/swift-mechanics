import SwiftMechanics

/// Immutable public source owner; invocation work remains exclusive to the caller.
final class ContactDerivativeProbeContext: Sendable {
    let source: ContactDerivativeProbeSource
    let policy: ContactDerivativePolicy

    init(source: ContactDerivativeProbeSource) throws(ContactDerivativeError) {
        self.source = source
        policy = try Self.policy()
    }

    @inline(never)
    func contact(using service: any ContactDifferentiating, input: ContactInput? = nil,
        pair: ContactLawPair? = nil, work: inout ContactDerivativeWork) throws(ContactDerivativeError) -> ContactResponseTangent {
        try service.contact(input: input ?? source.input, pair: pair ?? source.pair,
            accepted: source.accepted, direction: source.direction, policy: policy, work: &work)
    }

    @inline(never)
    func impact(using service: any ContactDifferentiating, approachSpeed: Double? = nil,
        work: inout ContactDerivativeWork) throws(ContactDerivativeError) -> ContactImpactTangent {
        try service.impact(pair: source.impactPair, approachSpeed: approachSpeed ?? source.approachSpeed,
            incomingNormalEnergy: source.incomingNormalEnergy, direction: source.impactDirection,
            policy: policy, work: &work)
    }

    static func sourceWork() throws(ContactLawError) -> ContactWork {
        ContactWork(budget: try ContactBudget(operations: 100000, scalarStorage: 1024, records: 2))
    }

    static func work() throws(ContactLawError) -> ContactDerivativeWork {
        ContactDerivativeWork(budget: try ContactBudget(operations: 100000, scalarStorage: 1024, records: 2))
    }

    static func policy() throws(ContactDerivativeError) -> ContactDerivativePolicy {
        let acceptance: ContactAcceptancePolicy
        do throws(ContactLawError) {
            acceptance = try ContactAcceptancePolicy(absoluteEnergyTolerance: 1e-10, absolutePowerTolerance: 1e-10,
                relativeTolerance: 1e-11, referenceEnergy: 1, referencePower: 1, coneTolerance: 1e-11)
        } catch { throw .law(error) }
        return try ContactDerivativePolicy(separationRadius: 0.001, normalSpeedRadius: 0.1,
            maximumIdentifierBytes: 1024, absolutePrimalTolerance: 1e-10, relativePrimalTolerance: 1e-11,
            acceptance: acceptance)
    }
}
