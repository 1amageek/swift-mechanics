public struct TopologyRuntimeContributors: RuntimeContributorHandling, Sendable {
    public let schemas:[RuntimeContributorSchema]
    public let providers:[any RuntimeContributorHandling]
    private let registrations:[String:Int]
    public init(providers:[any RuntimeContributorHandling],capacity:RuntimeCapacity) throws(RuntimeFailure) {
        guard providers.count <= capacity.maximumContributors else { throw RuntimeFailure(.capacityExceeded,message:"Topology provider catalog exceeds capacity.") }
        var schemas:[RuntimeContributorSchema]=[],metadata=0,owners:[String:Int]=[:]
        for (index,provider) in providers.enumerated() {
            let registrations=provider.schemas
            guard registrations.count <= capacity.maximumContributors-schemas.count else { throw RuntimeFailure(.capacityExceeded,message:"Topology schema catalog exceeds capacity.") }
            for schema in registrations {
                guard !schemas.contains(where: { $0.id == schema.id }),schema.maximumBytes <= capacity.maximumContributorBytes else { throw RuntimeFailure(.duplicateContributor,message:"Topology schema is duplicated or oversized.") }
                let (next,overflow)=metadata.addingReportingOverflow(schema.id.utf8.count)
                guard !overflow,next <= capacity.maximumMetadataBytes else { throw RuntimeFailure(.capacityExceeded,message:"Topology catalog metadata exceeds capacity.") };metadata=next
                schemas.append(schema)
                owners[schema.id]=index
            }
        }
        self.providers=providers;self.schemas=schemas.sorted { $0.id < $1.id };registrations=owners
    }
    public func validate(_ record:RuntimeContributorState,model:CompiledMechanicalModel,budget:RuntimeValidationBudget) throws(RuntimeFailure) -> RuntimeValidationEvidence {
        if let index=registrations[record.id] { return try providers[index].validate(record,model:model,budget:budget) }
        throw RuntimeFailure(.unknownContributor,contributor:record.id,message:"Topology target has no required validator.")
    }
    // FIXME(INCOMPLETE_IMPLEMENTATION): Generic migration has no complete accepted-source/catalog disposition proof.
    // Use the explicit topology preparing contract; unsupported supplier histories must remain failures.
    public func migrate(_ record:RuntimeContributorState,transition:ModelTransition,target:CompiledMechanicalModel,budget:RuntimeValidationBudget) throws(RuntimeFailure) -> RuntimeContributorState {
        throw RuntimeFailure(.incompatibleMigration,message:"Topology catalog migration requires explicit preparation.")
    }
}
