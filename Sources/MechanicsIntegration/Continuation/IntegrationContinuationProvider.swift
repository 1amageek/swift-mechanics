import MechanicsCompiler
import MechanicsJoints
import MechanicsCore
import MechanicsRuntime

@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
public struct IntegrationContinuationProvider: RuntimeContributorHandling, Sendable {
    public let descriptor: ODEDescriptor
    public let policy: ExplicitIntegrationPolicy
    public let schema: RuntimeContributorSchema
    private let signature: [UInt8]
    public var schemas: [RuntimeContributorSchema] { [schema] }
    public init(descriptor: ODEDescriptor, policy: ExplicitIntegrationPolicy) throws(RuntimeFailure) {
        guard descriptor.dimensions.count == policy.scales.count,
              zip(descriptor.dimensions, policy.scales).allSatisfy({ pair in pair.0 == pair.1.dimension }) else { throw RuntimeFailure(.invalidInput, message: "Error scales do not match each equation coordinate dimension.") }
        let n = descriptor.dimensions.count
        let (coordinateBytes, overflow) = n.multipliedReportingOverflow(by: 32)
        let identityBytes = descriptor.identity.utf8.count.addingReportingOverflow(descriptor.chart.utf8.count)
        let totalIDs = identityBytes.partialValue.addingReportingOverflow(descriptor.model.identity.utf8.count)
        let fixed = totalIDs.partialValue.addingReportingOverflow(136)
        let total = fixed.partialValue.addingReportingOverflow(coordinateBytes)
        guard !overflow, !identityBytes.overflow, !totalIDs.overflow, !fixed.overflow, !total.overflow,
              total.partialValue <= policy.maximumContinuationBytes else { throw RuntimeFailure(.capacityExceeded, message: "Integration signature/history exceeds explicit byte capacity.") }
        var data = IntegrationPayload(); data.bytes.reserveCapacity(total.partialValue)
        data.put(descriptor.identity); data.put(descriptor.chart); data.put(descriptor.model.identity); data.put(descriptor.model.revision)
        data.put(UInt64(policy.method.rawValue))
        for value in [policy.initialStep,policy.minimumStep,policy.maximumStep,policy.safety,policy.minimumFactor,policy.maximumFactor] { data.put(value) }
        data.put(UInt64(n))
        for (dimension, scale) in zip(descriptor.dimensions,policy.scales) {
            for exponent in [dimension.length,dimension.mass,dimension.time,dimension.angle,dimension.electricCurrent,dimension.temperature,dimension.amount,dimension.luminousIntensity] { data.bytes.append(UInt8(bitPattern: exponent)) }
            data.put(scale.absoluteSI); data.put(scale.relative)
        }
        signature = data.bytes; self.descriptor = descriptor; self.policy = policy
        let maximum = signature.count + 40 + 8*n
        guard maximum <= policy.maximumContinuationBytes else { throw RuntimeFailure(.capacityExceeded, message: "Integration payload exceeds capacity.") }
        schema = try RuntimeContributorSchema(id: "mechanics.integration.explicit.v1", category: .integrator, version: 1, maximumBytes: maximum)
    }
    public func initialRecord(physical: KinematicState, equations: any SmoothODEEquations) throws(RuntimeFailure) -> RuntimeContributorState {
        guard equations.descriptor == descriptor, physical.revision == descriptor.model.revision else { throw RuntimeFailure(.incompatibleModel, message: "Initial integration state/equation revision is incompatible.") }
        var point = [Double](repeating: .nan, count: descriptor.dimensions.count)
        try equations.read(physical, into: &point)
        return try record(IntegrationHistory(time: physical.time, point: point, nextStep: policy.initialStep, steps: 0, error: nil))
    }
    public func record(_ history: IntegrationHistory) throws(RuntimeFailure) -> RuntimeContributorState {
        try valid(history)
        var data = IntegrationPayload(bytes: signature); data.bytes.reserveCapacity(schema.maximumBytes)
        data.put(history.acceptedTime); data.put(history.nextStep); data.put(history.acceptedSteps)
        data.put(UInt64(history.normalizedError == nil ? 0 : 1))
        if let error = history.normalizedError { data.put(error) }
        for value in history.acceptedPoint { data.put(value) }
        return try RuntimeContributorState(id: schema.id, category: schema.category, version: schema.version, bytes: data.bytes)
    }
    public func history(_ record: RuntimeContributorState) throws(RuntimeFailure) -> IntegrationHistory {
        guard record.id == schema.id, record.category == schema.category, record.version == schema.version,
              record.bytes.count <= schema.maximumBytes else { throw RuntimeFailure(.invalidContributor, message: "Integration history schema/bounds mismatch.") }
        var data = IntegrationPayload(bytes: record.bytes); try data.expect(signature)
        let time = try data.scalar(), next = try data.scalar(), sequence = try data.integer(), flag = try data.integer()
        guard flag <= 1 else { throw RuntimeFailure(.invalidContributor, message: "Integration error availability flag is invalid.") }
        let error: Double? = flag == 1 ? try data.scalar() : nil
        var point: [Double] = []; point.reserveCapacity(descriptor.dimensions.count)
        for _ in descriptor.dimensions { point.append(try data.scalar()) }
        guard data.isAtEnd else { throw RuntimeFailure(.invalidContributor, message: "Integration history contains trailing fields.") }
        let value = IntegrationHistory(time: time, point: point, nextStep: next, steps: sequence, error: error); try valid(value); return value
    }
    public func associatedHistory(_ record: RuntimeContributorState, physical: KinematicState, equations: any SmoothODEEquations) throws(RuntimeFailure) -> IntegrationHistory {
        let value = try history(record)
        guard physical.revision == descriptor.model.revision, equations.descriptor == descriptor else { throw RuntimeFailure(.incompatibleModel, message: "History association model/chart is incompatible.") }
        var point = [Double](repeating: .nan, count: descriptor.dimensions.count)
        try equations.read(physical, into: &point)
        guard value.acceptedTime == physical.time, value.acceptedPoint == point else { throw RuntimeFailure(.invalidContributor, message: "Integration history differs from accepted physical time/point.") }
        return value
    }
    private func valid(_ value: IntegrationHistory) throws(RuntimeFailure) {
        guard value.acceptedTime.isFinite, value.nextStep.isFinite, value.nextStep >= policy.minimumStep, value.nextStep <= policy.maximumStep,
              value.acceptedPoint.count == descriptor.dimensions.count, value.acceptedPoint.allSatisfy({ $0.isFinite }),
              value.normalizedError.map({ $0.isFinite && $0 >= 0 && $0 <= 1 }) ?? true,
              (policy.method == .classicalRK4 ? value.normalizedError == nil : (value.acceptedSteps == 0 || value.normalizedError != nil)) else {
            throw RuntimeFailure(.invalidContributor, message: "Integration history point/time/error/step is invalid.")
        }
    }
    public func validate(_ record: RuntimeContributorState, model: CompiledMechanicalModel, budget: RuntimeValidationBudget) throws(RuntimeFailure) -> RuntimeValidationEvidence {
        guard model.stamp == descriptor.model else { throw RuntimeFailure(.incompatibleModel, message: "Integration history is bound to another compiled model/revision.") }
        guard record.bytes.count <= budget.workUnits, descriptor.dimensions.count <= budget.scratchBytes / 8 else { throw RuntimeFailure(.contributorBudgetExceeded, message: "Integration history validation exceeds explicit work/scratch budget.") }
        _ = try history(record)
        return try RuntimeValidationEvidence(workUnitsUsed: record.bytes.count, scratchBytesUsed: descriptor.dimensions.count*8)
    }
    public func migrate(_ record: RuntimeContributorState, transition: ModelTransition, target: CompiledMechanicalModel, budget: RuntimeValidationBudget) throws(RuntimeFailure) -> RuntimeContributorState {
        // FIXME(INCOMPLETE_IMPLEMENTATION): Runtime migration calls this equation-bound history provider.
        // An equation/chart certificate for the target model and history reset/preservation must be proved before success.
        throw RuntimeFailure(.incompatibleMigration, message: "Equation-bound integration history requires explicit reinitialization after model migration.")
    }
}
