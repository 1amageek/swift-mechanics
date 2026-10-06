/// Immutable original seed recipe and bounded, explicitly declared stochastic inputs.
public final class GranularRuntimeSource: Sendable {
    public let initial: GranularState
    public let carrier: ModelStamp
    public let policy: GranularPolicy
    public let timeStepSeconds: Double
    public let gravityChoices: [Vector3]
    public let maximumAcceptedSteps: Int
    public let maximumBytes: Int
    public let maximumMetadataBytes: Int
    public let physicsBudget: GranularRuntimePhysicsBudget
    public let schema: RuntimeContributorSchema
    public let requiredStorageBytes: Int
    internal let signature: [UInt8]
    @inline(never)
    public init(initial: GranularState, carrier: ModelStamp, policy: GranularPolicy, timeStepSeconds: Double,
                gravityChoices: [Vector3], maximumAcceptedSteps: Int, contributorID: String,
                maximumBytes: Int, maximumMetadataBytes: Int, physicsBudget: GranularRuntimePhysicsBudget,
                work: inout GranularRuntimeWork) throws(GranularRuntimeError) {
        try work.poll();guard !policy.isCancelled() else { throw .cancelled }
        guard maximumBytes >= 48,maximumMetadataBytes > 0,maximumAcceptedSteps > 0,
              timeStepSeconds.isFinite,timeStepSeconds > 0,!gravityChoices.isEmpty,
              gravityChoices.count <= maximumBytes/24,initial.steps == 0,initial.timeSeconds == 0,initial.random.draws == 0,
              initial.model.particles.count <= policy.maximumParticles,initial.model.boundaries.count <= policy.maximumBoundaries,
              !initial.model.bindings.isEmpty,initial.model.bindings.count <= policy.maximumContacts,
              initial.motions.count == initial.model.particles.count,initial.contacts.count == initial.model.bindings.count,
              work.physics.matches(physicsBudget) else { throw .invalidInput }
        let storage=try GranularJournalWire.sum(GranularJournalWire.product(3,maximumBytes),physicsBudget.logicalStorageBytes)
        try work.reserve(storage)
        let signature=try GranularSourceSignature.make(initial:initial,carrier:carrier,policy:policy,step:timeStepSeconds,
            choices:gravityChoices,steps:maximumAcceptedSteps,id:contributorID,maximum:maximumBytes,metadata:maximumMetadataBytes,
            budget:physicsBudget,work:&work)
        let size=try GranularJournalWire.sum(signature.count,GranularJournalWire.sum(48,GranularJournalWire.product(8,maximumAcceptedSteps)))
        guard size <= maximumBytes else { throw .capacityExceeded }
        for contact in initial.contacts {
            try work.charge(16)
            // FIXME(INCOMPLETE_IMPLEMENTATION): Arbitrary nonzero seed history has no public restore authority. This journal must start from genuine zero-step preparation until a separate lower restore contract is qualified.
            guard contact.basis == nil,contact.history.sequence == 0,contact.history.timeSeconds == 0,
                  contact.history.firstBristleDisplacement == 0,contact.history.secondBristleDisplacement == 0,
                  contact.history.cumulativeTangentialDissipation == 0 else { throw .unsupportedDomain }
        }
        self.initial=initial;self.carrier=carrier;self.policy=policy;self.timeStepSeconds=timeStepSeconds
        self.gravityChoices=gravityChoices;self.maximumAcceptedSteps=maximumAcceptedSteps;self.maximumBytes=maximumBytes
        self.maximumMetadataBytes=maximumMetadataBytes;self.physicsBudget=physicsBudget;self.signature=signature;requiredStorageBytes=storage
        do throws(RuntimeFailure) { schema=try RuntimeContributorSchema(id:contributorID,category:.constitutive,version:1,maximumBytes:size) }
        catch { throw .runtime(error) }
        try work.poll();guard !policy.isCancelled() else { throw .cancelled }
    }
    internal func poll(_ work: GranularRuntimeWork) throws(GranularRuntimeError) {
        try work.poll();guard !policy.isCancelled() else { throw .cancelled }
    }
}
