import SwiftMechanics

extension FoundationVerification {
    @inline(never)
    static func verifyPhysicalParameterIdentification() throws {
        let context = try ParameterIdentificationProbeContext()
        try verifyIdentifiedPhysicalParameters(context)
        try verifyUnidentifiablePhysicalParameters(context)
        print("Physical identification passed: original mass/dashpot force, information, reference covariance and rank refusal.")
    }

    @inline(never)
    private static func verifyIdentifiedPhysicalParameters(_ context: ParameterIdentificationProbeContext) throws {
        var workspace = context.workspace(), loadWork = context.loadWork()
        var supplierWork = try context.supplierWork(), work = context.work()
        let result = try context.estimate(workspace: &workspace, loadWork: &loadWork,
            supplierWork: &supplierWork, work: &work)
        try require(abs(result.massKilograms - 2) < 1e-8)
        try require(abs(result.dampingNewtonSecondsPerMeter - 0.5) < 1e-8)
        try require(result.originalForceResidualsNewtons.count == 2)
        try require(result.normalizedInformationMatrix.count == 4)
        try require(result.unconstrainedGaussianReferenceCovariance.count == 4)
        let expectedInformation = [2.0, -1, -1, 5]
        let expectedReferenceCovariance = [5.0 / 9, 1.0 / 9, 1.0 / 9, 2.0 / 9]
        for index in 0..<4 {
            try require(abs(result.normalizedInformationMatrix[index] - expectedInformation[index]) < 1e-8)
            try require(abs(result.unconstrainedGaussianReferenceCovariance[index] - expectedReferenceCovariance[index]) < 1e-8)
        }
        for index in 0..<2 {
            let observation = context.problem.observations[index]
            let force = result.massKilograms * observation.state.acceleration[context.fixture.velocityIndex]
                + result.dampingNewtonSecondsPerMeter * observation.state.v[context.fixture.velocityIndex]
            try require(abs(force - observation.appliedForceNewtons) < 1e-8)
            try require(abs(result.originalForceResidualsNewtons[index]) < 1e-8)
        }
        try require(abs(result.objective) < 1e-8 && result.originalStationarityResidual < 1e-8)
        try require(result.originalInformationResidual < 1e-8)
        try require(result.activeLowerBounds == [false, false] && result.activeUpperBounds == [false, false])
        try require(result.lowerBounds == context.problem.lowerBounds && result.upperBounds == context.problem.upperBounds)
        try require(result.noiseAssumption == .independentGaussianForceNoiseKnownVarianceWithExactKinematics)
        try require(result.identifiableNormalizedDirections == [1, 0, 0, 1])
        try require(result.work == work && work.operations > 0)
        try require(result.supplierWork == supplierWork && supplierWork.calls > 0)
        try require(result.loadWork.consumed == loadWork.consumed && loadWork.consumed > 0)
        try require(result.modelValidationAttempts > 0)
        try verifyIdentificationInputPreserved(context)
    }

    @inline(never)
    private static func verifyUnidentifiablePhysicalParameters(_ context: ParameterIdentificationProbeContext) throws {
        var workspace = context.workspace(), loadWork = context.loadWork()
        var supplierWork = try context.supplierWork(), work = context.work()
        var refused = false
        do throws(ParameterIdentificationFailure) {
            _ = try context.estimate(context.unidentifiableProblem, workspace: &workspace,
                loadWork: &loadWork, supplierWork: &supplierWork, work: &work)
        } catch {
            guard case .unidentifiable(let rank, let direction, let null, let residual) = error.cause,
                  rank == 1, direction.count == 2, null.count == 2 else {
                throw FoundationVerificationError.analyticCheckFailed
            }
            try require(abs(2 * null[0] + null[1]) < 1e-8 && residual < 1e-8)
            try require(abs(null[0]) + abs(null[1]) > 0)
            try require(error.phase == .identifiability && !error.failedSupplierWorkUnavailable)
            try require(error.work == work && error.supplierWork == supplierWork)
            try require(error.loadWork.consumed == loadWork.consumed)
            refused = true
        }
        try require(refused && work.operations > 0 && supplierWork.calls > 0 && loadWork.consumed > 0)
        try verifyIdentificationInputPreserved(context)
    }

    @inline(never)
    private static func verifyIdentificationInputPreserved(_ context: ParameterIdentificationProbeContext) throws {
        try require(context.problem.observations.count == 2 && context.unidentifiableProblem.observations.count == 2)
        let first = context.problem.observations[0], second = context.problem.observations[1]
        try require(first.state.q == [0] && first.state.v == [1] && first.state.acceleration == [1])
        try require(second.state.q == [0.3] && second.state.v == [-2] && second.state.acceleration == [1])
        try require(first.state.time == 0 && second.state.time == 1)
        try require(first.appliedForceNewtons == 2.5 && second.appliedForceNewtons == 1)
        try require(context.fixture.model.descriptor.initialState.q == [0])
        try require(context.fixture.model.descriptor.initialState.v == [0])
    }
}
