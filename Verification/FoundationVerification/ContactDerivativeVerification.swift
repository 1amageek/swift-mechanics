import SwiftMechanics

extension FoundationVerification {
    @inline(never)
    static func verifyContactDerivatives() throws {
        var sourceWork = try ContactDerivativeProbeContext.sourceWork()
        let source = try ContactDerivativeProbeSource(work: &sourceWork)
        let context = try ContactDerivativeProbeContext(source: source)
        let service: any ContactDifferentiating = ExactContactDifferentiator()
        var work = try ContactDerivativeProbeContext.work()
        let result = try context.contact(using: service, work: &work)
        try require(abs(result.primal.compressiveNormalForce - 20) < 1e-9)
        try require(abs(result.primal.normalStoredEnergy - 0.2) < 1e-9)
        try require(abs(result.primal.relativeMechanicalPower + 40) < 1e-9)
        try require(abs(result.compressiveNormalForce - 3) < 1e-9)
        try require(abs(result.normalStoredEnergy - 0.06) < 1e-9)
        try require(abs(result.relativeMechanicalPower - 2) < 1e-9)
        try require(abs(result.forceOnB.z - 3) < 1e-9 && result.forceOnB.x == 0 && result.forceOnB.y == 0)
        try require(result.normalDissipationPower == 0 && work.operations > 0)
        try require(result.validity.minimumSeparation < -0.02 && result.validity.maximumSeparation > -0.02)
        let impact = try context.impact(using: service, work: &work)
        try require(abs(impact.primal.reboundSpeed - 1.2) < 1e-9)
        try require(abs(impact.primal.retainedNormalEnergy - 1.44) < 1e-9)
        try require(abs(impact.primal.lostNormalEnergy - 2.56) < 1e-9)
        try require(abs(impact.reboundSpeed - 0.18) < 1e-9)
        try require(abs(impact.retainedNormalEnergy + 0.18) < 1e-9)
        try require(abs(impact.lostNormalEnergy + 0.32) < 1e-9)
        try require(impact.effectiveRestitution == 0)
        let touchingInput = try source.contactInput(separation: 0)
        var boundaryRefused = false
        do throws(ContactDerivativeError) {
            _ = try context.contact(using: service, input: touchingInput, work: &work)
        } catch {
            guard case .nonsmoothBoundary = error else { throw FoundationVerificationError.analyticCheckFailed }
            boundaryRefused = true
        }
        var thresholdRefused = false
        do throws(ContactDerivativeError) {
            _ = try context.impact(using: service, approachSpeed: 1, work: &work)
        } catch {
            guard case .nonsmoothBoundary = error else { throw FoundationVerificationError.analyticCheckFailed }
            thresholdRefused = true
        }
        let unsupportedSource = try ContactDerivativeProbeSource.unsupported(work: &sourceWork)
        let unsupported = try ContactDerivativeProbeContext(source: unsupportedSource)
        var unsupportedRefused = false
        do throws(ContactDerivativeError) {
            _ = try unsupported.contact(using: service, work: &work)
        } catch {
            guard case .unsupportedDomain = error else { throw FoundationVerificationError.analyticCheckFailed }
            unsupportedRefused = true
        }
        try require(boundaryRefused && thresholdRefused && unsupportedRefused)
        try require(source.accepted.sequence == 0 && source.input.startTimeSeconds == 0)
        print("Contact derivative public verification passed: original force, energy, power, restitution and branch refusal.")
    }
}
